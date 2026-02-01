Here is the complete, robust visual-regression-test.js script tailored for your automated agent workflow.
I have designed this script to be "Agent-Friendly" by ensuring it outputs strict JSON to stdout, making it easy for your VS Code agent to parse the results without regex guessing.

### 1. Prerequisites
The agent will need to run this once to set up the environment:
Bash

npm install puppeteer pixelmatch pngjs yargs
### 2. The Script (visual-regression-test.js)
JavaScript

const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer');
const PNG = require('pngjs').PNG;
const pixelmatch = require('pixelmatch');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

// Parse arguments
const argv = yargs(hideBin(process.argv))
  .option('url', { type: 'string', description: 'URL or local file path to test', demandOption: true })
  .option('baseline', { type: 'string', description: 'Path to baseline PNG image', demandOption: true })
  .option('output', { type: 'string', description: 'Path to save the diff image', default: 'diff.png' })
  .option('threshold', { type: 'number', description: 'Matching threshold (0 to 1)', default: 0.1 })
  .option('generate', { type: 'boolean', description: 'Force generate/update baseline image', default: false })
  .help()
  .argv;

(async () => {
  const browser = await puppeteer.launch({
    headless: "new",
    args: ['--no-sandbox', '--disable-setuid-sandbox'] // Safer for containerized/agent envs
  });

  try {
    const page = await browser.newPage();
    
    // Set a consistent viewport to ensure reproducibility
    await page.setViewport({ width: 1280, height: 800 });

    // Handle local files vs remote URLs
    const targetUrl = argv.url.startsWith('http') 
      ? argv.url 
      : `file://${path.resolve(argv.url)}`;

    await page.goto(targetUrl, { waitUntil: 'networkidle0' });

    // Take the screenshot
    const screenshotBuffer = await page.screenshot({ fullPage: true });
    const currentPng = PNG.sync.read(screenshotBuffer);

    // MODE 1: Generate Baseline (if requested or if file missing)
    if (argv.generate || !fs.existsSync(argv.baseline)) {
      fs.writeFileSync(argv.baseline, PNG.sync.write(currentPng));
      console.log(JSON.stringify({
        status: "BASELINE_CREATED",
        message: `Baseline image created at ${argv.baseline}`,
        diffPercentage: 0,
        passed: true
      }));
      await browser.close();
      process.exit(0);
    }

    // MODE 2: Compare against Baseline
    const baselinePng = PNG.sync.read(fs.readFileSync(argv.baseline));

    // Ensure dimensions match (resize logic could go here, but fail fast is safer for agents)
    if (currentPng.width !== baselinePng.width || currentPng.height !== baselinePng.height) {
      console.log(JSON.stringify({
        status: "DIMENSION_MISMATCH",
        message: `Dimensions differ. Baseline: ${baselinePng.width}x${baselinePng.height}, Current: ${currentPng.width}x${currentPng.height}`,
        passed: false
      }));
      await browser.close();
      process.exit(1);
    }

    // Create diff image buffer
    const diffPng = new PNG({ width: baselinePng.width, height: baselinePng.height });

    // Run Pixelmatch
    const numDiffPixels = pixelmatch(
      baselinePng.data,
      currentPng.data,
      diffPng.data,
      baselinePng.width,
      baselinePng.height,
      { threshold: argv.threshold }
    );

    const totalPixels = baselinePng.width * baselinePng.height;
    const diffPercentage = (numDiffPixels / totalPixels) * 100;

    // Write diff file for human inspection if needed
    fs.writeFileSync(argv.output, PNG.sync.write(diffPng));

    // Define pass criteria (e.g., < 0.1% difference)
    const passed = diffPercentage < 0.5; // Adjust tolerance as needed

    // Final JSON Output for the Agent
    console.log(JSON.stringify({
      status: passed ? "PASS" : "FAIL",
      diffPercentage: diffPercentage.toFixed(4),
      diffPixels: numDiffPixels,
      diffImagePath: path.resolve(argv.output),
      passed: passed
    }));

  } catch (error) {
    console.error(JSON.stringify({
      status: "ERROR",
      message: error.message,
      passed: false
    }));
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
---
### 3. How to Integrate into Your Agent Workflow
Update your **"Debugging JSON-Embedded CSS Pattern"** instructions with these commands.
#### Scenario A: First Run (Establishing the Truth)
The agent needs to know what "Correct" looks like. It should render the initial validated JSON and save it as the baseline.
Bash

# Agent Command:
node visual-regression-test.js --url test-render.html --baseline baseline.png --generate
**Agent Logic:** "I have created the baseline. Any future changes will be compared against this."
#### Scenario B: The Iteration Loop (Verifying Fixes)
When the agent tweaks the JSON/CSS to fix a bug, it runs the comparison.
Bash

# Agent Command:
node visual-regression-test.js —url test-render.html —baseline baseline.png —output diff-iteration-2.png
**Parsing the Output:**
The agent should look for the passed boolean in the JSON response.
- **If true:** “Visuals match the baseline. Proceeding.”
- **If false:** “Visual regression detected (2.4% difference). I will analyze diff-iteration-2.png or revert the last change.”
### 4. Why This Specific Script?
1. **JSON Stdout:** Most CLI tools output unstructured text. This outputs clean JSON, meaning your agent doesn’t need regex to figure out if it passed. It just parses JSON.parse(stdout).passed.
2. **—generate Flag:** This solves the “Cold Start” problem. The agent can self-bootstrap its testing environment.
3. **Local File Support:** It explicitly handles the file:// protocol, so you don’t need to spin up a localhost server just to test a static HTML file.
