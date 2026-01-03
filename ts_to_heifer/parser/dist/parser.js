"use strict";
/**
 * TypeScript to JSON AST Parser (Phase 1)
 *
 * Uses TypeScript Compiler API to parse TypeScript source code
 * and output a simplified JSON AST for the OCaml translator.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const ts = __importStar(require("typescript"));
const fs = __importStar(require("fs"));
/**
 * Extracts JSDoc comments from a node, looking for @requires and @ensures tags.
 */
function serializeJSDoc(node, sourceFile) {
    const jsDocTags = ts.getJSDocTags(node);
    if (!jsDocTags || jsDocTags.length === 0) {
        return null;
    }
    const result = {};
    for (const tag of jsDocTags) {
        const tagName = tag.tagName.text;
        const tagComment = typeof tag.comment === 'string'
            ? tag.comment
            : tag.comment
                ? Array.from(tag.comment)
                    .map(c => c.getText(sourceFile))
                    .join('')
                : '';
        if (tagName === 'require' || tagName === 'ensure') {
            result[tagName] = tagComment.trim();
        }
    }
    return Object.keys(result).length > 0 ? result : null;
}
/**
 * Serialize a TypeScript node to JSON
 */
function serializeNode(node, sourceFile) {
    const kind = ts.SyntaxKind[node.kind];
    const result = { kind };
    // Handle different node types
    switch (node.kind) {
        case ts.SyntaxKind.NumericLiteral:
            const numLiteral = node;
            result.value = parseFloat(numLiteral.text);
            break;
        case ts.SyntaxKind.StringLiteral:
            const strLiteral = node;
            result.value = strLiteral.text;
            break;
        case ts.SyntaxKind.Identifier:
            const identifier = node;
            result.text = identifier.text;
            break;
        case ts.SyntaxKind.BinaryExpression:
            const binary = node;
            // Get operator name, avoiding aliases like FirstBinaryOperator
            const opKind = binary.operatorToken.kind;
            result.operator = ts.tokenToString(opKind) || ts.SyntaxKind[opKind];
            result.left = serializeNode(binary.left, sourceFile);
            result.right = serializeNode(binary.right, sourceFile);
            break;
        case ts.SyntaxKind.PrefixUnaryExpression:
            const prefix = node;
            result.operator = ts.SyntaxKind[prefix.operator];
            result.operand = serializeNode(prefix.operand, sourceFile);
            break;
        case ts.SyntaxKind.PostfixUnaryExpression:
            const postfix = node;
            result.operator = ts.SyntaxKind[postfix.operator];
            result.operand = serializeNode(postfix.operand, sourceFile);
            break;
        case ts.SyntaxKind.VariableStatement:
            const varStmt = node;
            result.declarationList = serializeNode(varStmt.declarationList, sourceFile);
            break;
        case ts.SyntaxKind.VariableDeclarationList:
            const declList = node;
            result.declarations = declList.declarations.map(d => serializeNode(d, sourceFile));
            result.flags = declList.flags; // Include flags to distinguish const/let/var
            break;
        case ts.SyntaxKind.VariableDeclaration:
            const decl = node;
            result.name = serializeNode(decl.name, sourceFile);
            if (decl.type) {
                result.type = serializeNode(decl.type, sourceFile);
            }
            if (decl.initializer) {
                result.initializer = serializeNode(decl.initializer, sourceFile);
            }
            break;
        case ts.SyntaxKind.ExpressionStatement:
            const exprStmt = node;
            result.expression = serializeNode(exprStmt.expression, sourceFile);
            break;
        case ts.SyntaxKind.ReturnStatement:
            const returnStmt = node;
            if (returnStmt.expression) {
                result.expression = serializeNode(returnStmt.expression, sourceFile);
            }
            break;
        case ts.SyntaxKind.IfStatement:
            const ifStmt = node;
            result.expression = serializeNode(ifStmt.expression, sourceFile);
            result.thenStatement = serializeNode(ifStmt.thenStatement, sourceFile);
            if (ifStmt.elseStatement) {
                result.elseStatement = serializeNode(ifStmt.elseStatement, sourceFile);
            }
            break;
        case ts.SyntaxKind.Block:
            const block = node;
            result.statements = block.statements.map(s => serializeNode(s, sourceFile));
            break;
        case ts.SyntaxKind.CallExpression:
            const call = node;
            result.expression = serializeNode(call.expression, sourceFile);
            result.arguments = call.arguments.map(arg => serializeNode(arg, sourceFile));
            break;
        case ts.SyntaxKind.FunctionDeclaration:
            const funcDecl = node;
            const jsdoc = serializeJSDoc(node, sourceFile);
            if (jsdoc) {
                result.jsdoc = jsdoc;
            }
            if (funcDecl.name) {
                result.name = serializeNode(funcDecl.name, sourceFile);
            }
            result.parameters = funcDecl.parameters.map(p => serializeNode(p, sourceFile));
            if (funcDecl.type) {
                result.type = serializeNode(funcDecl.type, sourceFile);
            }
            if (funcDecl.body) {
                result.body = serializeNode(funcDecl.body, sourceFile);
            }
            break;
        case ts.SyntaxKind.Parameter:
            const param = node;
            result.name = serializeNode(param.name, sourceFile);
            if (param.type) {
                result.type = serializeNode(param.type, sourceFile);
            }
            break;
        case ts.SyntaxKind.WhileStatement:
            const whileStmt = node;
            result.expression = serializeNode(whileStmt.expression, sourceFile);
            result.statement = serializeNode(whileStmt.statement, sourceFile);
            break;
        case ts.SyntaxKind.ForStatement:
            const forStmt = node;
            if (forStmt.initializer) {
                result.initializer = serializeNode(forStmt.initializer, sourceFile);
            }
            if (forStmt.condition) {
                result.condition = serializeNode(forStmt.condition, sourceFile);
            }
            if (forStmt.incrementor) {
                result.incrementor = serializeNode(forStmt.incrementor, sourceFile);
            }
            result.statement = serializeNode(forStmt.statement, sourceFile);
            break;
        // Type keywords
        case ts.SyntaxKind.NumberKeyword:
        case ts.SyntaxKind.StringKeyword:
        case ts.SyntaxKind.BooleanKeyword:
        case ts.SyntaxKind.VoidKeyword:
        case ts.SyntaxKind.AnyKeyword:
        case ts.SyntaxKind.TrueKeyword:
        case ts.SyntaxKind.FalseKeyword:
            // These just need their kind
            break;
        default:
            // For unsupported nodes, try to recursively serialize children
            ts.forEachChild(node, child => {
                if (!result.children) {
                    result.children = [];
                }
                result.children.push(serializeNode(child, sourceFile));
            });
    }
    return result;
}
/**
 * Parse TypeScript source file to JSON AST
 */
function parseTypeScript(fileName) {
    const sourceCode = fs.readFileSync(fileName, 'utf-8');
    // Create source file
    const sourceFile = ts.createSourceFile(fileName, sourceCode, ts.ScriptTarget.Latest, true);
    // Serialize to JSON
    return {
        kind: 'SourceFile',
        fileName: fileName,
        statements: sourceFile.statements.map(stmt => serializeNode(stmt, sourceFile))
    };
}
/**
 * Main CLI
 */
function main() {
    const args = process.argv.slice(2);
    if (args.length < 1) {
        console.error('Usage: node parser.js <input.ts> [output.json]');
        process.exit(1);
    }
    const inputFile = args[0];
    const outputFile = args[1] || inputFile.replace(/\.ts$/, '.json');
    try {
        console.log(`Parsing ${inputFile}...`);
        const ast = parseTypeScript(inputFile);
        const jsonOutput = JSON.stringify(ast, null, 2);
        fs.writeFileSync(outputFile, jsonOutput);
        console.log(`✓ AST written to ${outputFile}`);
        console.log(`  Statements: ${ast.statements.length}`);
    }
    catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}
main();
