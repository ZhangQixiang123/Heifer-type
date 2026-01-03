import * as cp from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as assert from 'assert';

// process.argv[1] is the path to the script being executed.
// We can derive the paths we need from it, regardless of module system.
const scriptDir = path.dirname(process.argv[1]);

const parserScript = path.resolve(scriptDir, '../../ts_to_heifer/parser/src/parser.ts');
const testFile = path.resolve(scriptDir, './assets/jsdoc_test.ts');
const outputFile = testFile.replace(/\.ts$/, '.json');


console.log('--- Running JSDoc Parser Test ---');

// 1. Run the parser on the test file
const command = `npx ts-node "${parserScript}" "${testFile}"`;
console.log(`Executing: ${command}`);

try {
    cp.execSync(command);
} catch (e) {
    console.error("Parser execution failed.", e);
    process.exit(1);
}

console.log('Parser executed successfully.');

// 2. Read the output JSON
let ast: any;
try {
    const jsonOutput = fs.readFileSync(outputFile, 'utf-8');
    ast = JSON.parse(jsonOutput);
    console.log('Successfully read and parsed output AST.');
} catch (e) {
    console.error(`Failed to read or parse output file: ${outputFile}`, e);
    process.exit(1);
}

// 3. Assert the content is correct
try {
    assert.ok(ast.statements.length > 0, "No statements found in AST");
    const funcDecl = ast.statements[0];
    assert.strictEqual(funcDecl.kind, 'FunctionDeclaration', "First statement is not a FunctionDeclaration");

    const expectedJSDoc = {
        requires: 'x > 0',
        ensures: 'result > x',
    };

    console.log('Performing assertions...');
    assert.deepStrictEqual(funcDecl.jsdoc, expectedJSDoc, "JSDoc does not match expected output");

    console.log('✓ JSDoc test passed!');

} catch (e) {
    console.error('✗ JSDoc test failed!');
    console.error(e);
    process.exit(1);
} 