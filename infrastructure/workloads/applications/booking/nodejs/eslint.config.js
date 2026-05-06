const globals = require("globals");
const pluginJs = require("@eslint/js");

module.exports = [
  pluginJs.configs.recommended, // Use ESLint recommended rules
  {
    languageOptions: {
      sourceType: "commonjs",     // Set to "module" for ES Modules
      globals: {
        ...globals.node,          // Adds Node.js globals like 'process' and 'require'
      },
    },
    rules: {
      "no-unused-vars": "warn",   // Example rule: warn about unused variables
      "no-undef": "error",        // Example rule: error on undefined variables
    },
  },
];
