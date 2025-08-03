#!/usr/bin/env ts-node

import { spawn } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

interface TestSuite {
  name: string;
  command: string;
  description: string;
  required: boolean;
  timeout: number;
}

interface TestResult {
  suite: string;
  success: boolean;
  duration: number;
  coverage?: number;
  errors?: string[];
}

class UITestRunner {
  private testSuites: TestSuite[] = [
    {
      name: 'Unit Tests',
      command: 'npm run test:ui',
      description: 'Individual UI component unit tests',
      required: true,
      timeout: 60000
    },
    {
      name: 'Integration Tests', 
      command: 'npm run test:integration',
      description: 'User workflow integration tests',
      required: true,
      timeout: 120000
    },
    {
      name: 'Accessibility Tests',
      command: 'npm run test:accessibility',
      description: 'WCAG 2.1 AA compliance tests',
      required: true,
      timeout: 90000
    },
    {
      name: 'Performance Tests',
      command: 'npm run test:performance', 
      description: 'Component rendering performance tests',
      required: false,
      timeout: 180000
    },
    {
      name: 'Visual Regression Tests',
      command: 'npm run test:visual',
      description: 'Cross-browser visual consistency tests',
      required: false,
      timeout: 300000
    }
  ];

  private results: TestResult[] = [];

  async run(): Promise<void> {
    console.log('🚀 Starting Comprehensive UI Test Suite');
    console.log('==========================================');
    console.log();

    // Create test results directory
    const resultsDir = path.join(process.cwd(), 'test-results');
    if (!fs.existsSync(resultsDir)) {
      fs.mkdirSync(resultsDir, { recursive: true });
    }

    // Run all test suites
    for (const suite of this.testSuites) {
      console.log(`📋 Running ${suite.name}...`);
      console.log(`   ${suite.description}`);
      
      const result = await this.runTestSuite(suite);
      this.results.push(result);
      
      if (result.success) {
        console.log(`✅ ${suite.name} completed successfully`);
        if (result.coverage) {
          console.log(`   Coverage: ${result.coverage.toFixed(2)}%`);
        }
      } else {
        console.log(`❌ ${suite.name} failed`);
        if (result.errors) {
          result.errors.forEach(error => {
            console.log(`   Error: ${error}`);
          });
        }
        
        if (suite.required) {
          console.log(`⚠️  Required test suite failed. Stopping execution.`);
          break;
        }
      }
      
      console.log(`   Duration: ${(result.duration / 1000).toFixed(2)}s`);
      console.log();
    }

    // Generate comprehensive report
    await this.generateReport();
    
    // Print summary
    this.printSummary();
    
    // Exit with appropriate code
    const hasFailures = this.results.some(r => !r.success && this.testSuites.find(s => s.name === r.suite)?.required);
    process.exit(hasFailures ? 1 : 0);
  }

  private async runTestSuite(suite: TestSuite): Promise<TestResult> {
    const startTime = Date.now();
    
    try {
      const result = await this.executeCommand(suite.command, suite.timeout);
      const duration = Date.now() - startTime;
      
      // Parse coverage from result if available
      const coverage = this.parseCoverage(result.output);
      
      return {
        suite: suite.name,
        success: result.success,
        duration,
        coverage,
        errors: result.success ? undefined : [result.error || 'Unknown error']
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      
      return {
        suite: suite.name,
        success: false,
        duration,
        errors: [error instanceof Error ? error.message : String(error)]
      };
    }
  }

  private executeCommand(command: string, timeout: number): Promise<{
    success: boolean;
    output: string;
    error?: string;
  }> {
    return new Promise((resolve) => {
      const [cmd, ...args] = command.split(' ');
      const child = spawn(cmd, args, { 
        stdio: 'pipe',
        shell: true
      });

      let output = '';
      let errorOutput = '';

      child.stdout?.on('data', (data) => {
        output += data.toString();
      });

      child.stderr?.on('data', (data) => {
        errorOutput += data.toString();
      });

      const timer = setTimeout(() => {
        child.kill();
        resolve({
          success: false,
          output,
          error: `Test suite timed out after ${timeout}ms`
        });
      }, timeout);

      child.on('close', (code) => {
        clearTimeout(timer);
        resolve({
          success: code === 0,
          output,
          error: code !== 0 ? errorOutput : undefined
        });
      });

      child.on('error', (error) => {
        clearTimeout(timer);
        resolve({
          success: false,
          output,
          error: error.message
        });
      });
    });
  }

  private parseCoverage(output: string): number | undefined {
    // Look for coverage patterns in output
    const coveragePatterns = [
      /All files\s+\|\s+(\d+\.?\d*)/,
      /Statements\s+:\s+(\d+\.?\d*)%/,
      /Coverage:\s+(\d+\.?\d*)%/
    ];

    for (const pattern of coveragePatterns) {
      const match = output.match(pattern);
      if (match) {
        return parseFloat(match[1]);
      }
    }

    return undefined;
  }

  private async generateReport(): Promise<void> {
    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        total: this.results.length,
        passed: this.results.filter(r => r.success).length,
        failed: this.results.filter(r => !r.success).length,
        duration: this.results.reduce((sum, r) => sum + r.duration, 0)
      },
      coverage: {
        average: this.calculateAverageCoverage(),
        target: 80,
        met: this.calculateAverageCoverage() >= 80
      },
      results: this.results,
      environment: {
        node: process.version,
        platform: process.platform,
        arch: process.arch,
        cwd: process.cwd()
      }
    };

    // Write JSON report
    const jsonPath = path.join(process.cwd(), 'test-results', 'ui-test-report.json');
    fs.writeFileSync(jsonPath, JSON.stringify(report, null, 2));

    // Write HTML report
    await this.generateHTMLReport(report, path.join(process.cwd(), 'test-results', 'ui-test-report.html'));
  }

  private calculateAverageCoverage(): number {
    const coverageResults = this.results.filter(r => r.coverage !== undefined);
    if (coverageResults.length === 0) return 0;
    
    const sum = coverageResults.reduce((sum, r) => sum + (r.coverage || 0), 0);
    return sum / coverageResults.length;
  }

  private async generateHTMLReport(report: any, filePath: string): Promise<void> {
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UI Test Report - ${new Date(report.timestamp).toLocaleDateString()}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: #007bff; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; }
        .header .subtitle { opacity: 0.9; margin-top: 5px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; padding: 20px; }
        .metric { text-align: center; }
        .metric-value { font-size: 2rem; font-weight: bold; margin-bottom: 5px; }
        .metric-label { color: #666; font-size: 0.9rem; }
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .warning { color: #ffc107; }
        .results { padding: 0 20px 20px; }
        .test-suite { border: 1px solid #ddd; border-radius: 6px; margin-bottom: 15px; overflow: hidden; }
        .suite-header { background: #f8f9fa; padding: 15px; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; }
        .suite-name { font-weight: bold; }
        .suite-status { padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; font-weight: bold; }
        .suite-status.success { background: #d4edda; color: #155724; }
        .suite-status.error { background: #f8d7da; color: #721c24; }
        .suite-details { padding: 15px; }
        .coverage-bar { background: #e9ecef; height: 20px; border-radius: 10px; overflow: hidden; margin: 10px 0; }
        .coverage-fill { height: 100%; background: linear-gradient(90deg, #dc3545 0%, #ffc107 50%, #28a745 100%); transition: width 0.3s ease; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>UI Component Test Report</h1>
            <div class="subtitle">Generated on ${new Date(report.timestamp).toLocaleString()}</div>
        </div>
        
        <div class="summary">
            <div class="metric">
                <div class="metric-value ${report.summary.passed === report.summary.total ? 'success' : 'error'}">
                    ${report.summary.passed}/${report.summary.total}
                </div>
                <div class="metric-label">Tests Passed</div>
            </div>
            <div class="metric">
                <div class="metric-value ${report.coverage.met ? 'success' : 'warning'}">
                    ${report.coverage.average.toFixed(1)}%
                </div>
                <div class="metric-label">Average Coverage</div>
            </div>
            <div class="metric">
                <div class="metric-value">${(report.summary.duration / 1000).toFixed(1)}s</div>
                <div class="metric-label">Total Duration</div>
            </div>
        </div>
        
        <div class="results">
            <h2>Test Suite Results</h2>
            ${report.results.map((result: any) => `
                <div class="test-suite">
                    <div class="suite-header">
                        <div>
                            <div class="suite-name">${result.suite}</div>
                            <div style="font-size: 0.9rem; color: #666; margin-top: 5px;">
                                Duration: ${(result.duration / 1000).toFixed(2)}s
                            </div>
                        </div>
                        <div class="suite-status ${result.success ? 'success' : 'error'}">
                            ${result.success ? 'PASSED' : 'FAILED'}
                        </div>
                    </div>
                    ${result.coverage ? `
                        <div class="suite-details">
                            <div>Coverage: ${result.coverage.toFixed(2)}%</div>
                            <div class="coverage-bar">
                                <div class="coverage-fill" style="width: ${result.coverage}%"></div>
                            </div>
                        </div>
                    ` : ''}
                    ${result.errors ? `
                        <div class="suite-details">
                            <strong>Errors:</strong>
                            <ul>
                                ${result.errors.map((error: string) => `<li>${error}</li>`).join('')}
                            </ul>
                        </div>
                    ` : ''}
                </div>
            `).join('')}
        </div>
    </div>
</body>
</html>`;

    fs.writeFileSync(filePath, html);
  }

  private printSummary(): void {
    console.log('📊 Test Suite Summary');
    console.log('====================');
    console.log();
    
    const passed = this.results.filter(r => r.success).length;
    const total = this.results.length;
    const coverage = this.calculateAverageCoverage();
    const duration = this.results.reduce((sum, r) => sum + r.duration, 0);
    
    console.log(`✅ Tests Passed: ${passed}/${total}`);
    console.log(`📈 Coverage: ${coverage.toFixed(2)}% (Target: 80%)`);
    console.log(`⏱️  Total Duration: ${(duration / 1000).toFixed(2)}s`);
    console.log();
    
    if (coverage >= 80) {
      console.log('🎉 Coverage target met!');
    } else {
      console.log('⚠️  Coverage below target. Consider adding more tests.');
    }
    
    if (passed === total) {
      console.log('🎉 All tests passed!');
    } else {
      console.log('❌ Some tests failed. Check the detailed report.');
    }
    
    console.log();
    console.log(`📄 Detailed report: test-results/ui-test-report.html`);
    console.log(`📊 JSON report: test-results/ui-test-report.json`);
  }
}

// Run the test suite
if (require.main === module) {
  const runner = new UITestRunner();
  runner.run().catch(error => {
    console.error('Test runner failed:', error);
    process.exit(1);
  });
}

export { UITestRunner };