#!/usr/bin/env node
'use strict';

// Full-stack release/update robustness test for m1-fixture-agent.
//
// Each cycle: pushes a dummy marker commit to the 6 tracked component repos,
// builds, publishes, waits `interval` minutes for the fixture-agent to poll
// and install, then checks whether each of the 6 tracked versions actually
// changed, and runs one real ICT test via the REST server as a functional
// smoke check. Repeats for `runs` cycles, continuing past any cycle failure.
// Writes a full markdown report + raw JSON log under ./results/<timestamp>/.
//
// Usage:
//   node release-validation-cycle.js
// Takes no arguments: cycle interval matches the fixture-agent's fixed
// 10-minute poll interval, and the run count is fixed at 6.

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const REST_BASE = process.env.M1_REST_SERVER_URL || 'http://localhost:3300';

const intervalMinutes = 10;
const numRuns = 6;

const TRACKED = [
    { label: 'UI (gui-react)', repo: 'm1-operator-ui', configKey: 'uiSnapVersion' },
    { label: 'REST Server', repo: 'm1-rest-server', configKey: 'restServerSnapVersion' },
    { label: 'm1tfc', repo: 'm1tfc', configKey: 'm1tfcSnapVersion' },
    { label: 'm1-fixture-agent', repo: 'm1-fixture-agent', configKey: 'm1FixtureAgentSnapVersion' },
    { label: 'M1TB Board FW', repo: 'm1testBoardFw', configKey: 'm1tb.fwrev' },
    { label: 'STM32MP1 Bare Metal', repo: 'stm32mp1-baremetal', configKey: 'stm32mp1FW' }
];

const runStamp = new Date().toISOString().replace(/[:.]/g, '-');
const resultsDir = path.join(__dirname, 'results', runStamp);
fs.mkdirSync(resultsDir, { recursive: true });
const rawLogPath = path.join(resultsDir, 'raw.log');
const reportPath = path.join(resultsDir, 'report.md');
const jsonPath = path.join(resultsDir, 'data.json');

function log(line) {
    const stamped = `[${new Date().toISOString()}] ${line}`;
    console.log(stamped);
    fs.appendFileSync(rawLogPath, `${stamped}\n`);
}

function sh(cmd, cwd) {
    log(`$ ${cmd}  (cwd=${cwd})`);
    try {
        const out = execSync(cmd, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
        fs.appendFileSync(rawLogPath, `${out}\n`);
        return { ok: true, output: out };
    } catch (err) {
        const out = `${err.stdout || ''}\n${err.stderr || ''}`;
        fs.appendFileSync(rawLogPath, `${out}\n`);
        log(`COMMAND FAILED: ${cmd} :: ${err.message}`);
        return { ok: false, output: out, error: err.message };
    }
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function getNested(obj, dottedKey) {
    return dottedKey.split('.').reduce((o, k) => (o === undefined || o === null ? o : o[k]), obj);
}

async function getConfig() {
    const res = await fetch(`${REST_BASE}/config`);
    return res.json();
}

async function runIct(serial) {
    const res = await fetch(`${REST_BASE}/command`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command: 'ict', argument: `-b new -s ${serial}` })
    });
    return res.json();
}

function dummyCommitAndPush(repo, cycle) {
    const dir = path.join(REPO_ROOT, 'components', repo);
    const markerFile = path.join(dir, '.ai-release-cycle-marker');
    const ts = new Date().toISOString();
    fs.appendFileSync(markerFile, `cycle${cycle} ${ts}\n`);

    const add = sh('git add .ai-release-cycle-marker', dir);
    const commit = sh(`git commit -m "AI release-validation cycle ${cycle} marker (${ts})"`, dir);
    const push = sh('git push', dir);
    const headHash = sh('git rev-parse --short HEAD', dir);

    return {
        repo,
        ok: add.ok && commit.ok && push.ok,
        commitHash: headHash.ok ? headHash.output.trim() : null,
        add,
        commit,
        push
    };
}

async function runCycle(cycle) {
    log(`===== Cycle ${cycle}/${numRuns} starting =====`);

    const before = await getConfig();
    log(`Config before cycle ${cycle}: ${JSON.stringify(before)}`);

    const commits = TRACKED.map(t => dummyCommitAndPush(t.repo, cycle));

    const build = sh('scripts/build.sh', REPO_ROOT);
    const publish = sh('scripts/publish-fw.sh', REPO_ROOT);

    log(`Waiting ${intervalMinutes} minute(s) for fixture-agent poll cycle...`);
    await sleep(intervalMinutes * 60 * 1000);

    // stm32mp1FW is only refreshed by the ICT run itself (writes the fw-rev
    // file read back on the next /config call), so ICT must run before the
    // "after" snapshot is taken, not after.
    const serial = `AI-CYCLE-${cycle}`;
    let ict;
    try {
        ict = await runIct(serial);
    } catch (err) {
        ict = { status: 'FAILED', ErrorDescription: `Request error: ${err.message}` };
    }

    const after = await getConfig();
    log(`Config after cycle ${cycle}: ${JSON.stringify(after)}`);

    const versionChanges = TRACKED.map((t, idx) => {
        const beforeVal = getNested(before, t.configKey);
        const afterVal = getNested(after, t.configKey);
        return {
            label: t.label,
            repo: t.repo,
            configKey: t.configKey,
            beforeVal,
            afterVal,
            expectedCommit: commits[idx].commitHash,
            changed: beforeVal !== afterVal
        };
    });

    const cycleResult = {
        cycle,
        startedAt: new Date().toISOString(),
        buildOk: build.ok,
        publishOk: publish.ok,
        commits,
        before,
        after,
        versionChanges,
        ict
    };

    log(`===== Cycle ${cycle}/${numRuns} finished. ICT status=${ict.status} =====`);
    return cycleResult;
}

function renderMarkdown(results) {
    const lines = [];
    lines.push('# m1-fixture-agent Release Validation Report');
    lines.push('');
    lines.push(`Run timestamp: ${runStamp}`);
    lines.push(`Interval: ${intervalMinutes} minute(s), Cycles: ${numRuns}`);
    lines.push('');

    for (const r of results) {
        lines.push(`## Cycle ${r.cycle}`);
        lines.push('');
        lines.push(`- Build succeeded: ${r.buildOk}`);
        lines.push(`- Publish succeeded: ${r.publishOk}`);
        lines.push(`- ICT status: ${r.ict.status} (errorCode=${r.ict.errorCode ?? 'n/a'})`);
        lines.push('');
        lines.push('| Component | Before | After | Expected Commit | Changed |');
        lines.push('|---|---|---|---|---|');
        for (const v of r.versionChanges) {
            lines.push(`| ${v.label} | ${v.beforeVal} | ${v.afterVal} | ${v.expectedCommit} | ${v.changed ? 'YES' : 'NO'} |`);
        }
        lines.push('');
    }

    const allChanged = results.every(r => r.versionChanges.every(v => v.changed));
    const allIctOk = results.every(r => r.ict.status === 'OK');
    lines.push('## Summary');
    lines.push('');
    lines.push(`- All 6 tracked versions changed in every cycle: ${allChanged}`);
    lines.push(`- ICT passed in every cycle: ${allIctOk}`);

    return lines.join('\n');
}

async function main() {
    log(`Starting release-validation-cycle: interval=${intervalMinutes}min, runs=${numRuns}`);
    const results = [];
    for (let cycle = 1; cycle <= numRuns; cycle += 1) {
        try {
            const result = await runCycle(cycle);
            results.push(result);
        } catch (err) {
            log(`Cycle ${cycle} threw an unexpected error: ${err.stack || err.message}`);
            results.push({ cycle, error: err.message, versionChanges: [], ict: { status: 'FAILED', errorCode: -1 } });
        }
    }

    fs.writeFileSync(jsonPath, JSON.stringify(results, null, 2));
    fs.writeFileSync(reportPath, renderMarkdown(results));
    log(`Report written to ${reportPath}`);
    log(`Raw data written to ${jsonPath}`);
}

main().catch(err => {
    log(`FATAL: ${err.stack || err.message}`);
    process.exit(1);
});
