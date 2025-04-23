// eslint.config.js
export default [
  {
    languageOptions: {
      globals: {
        es6: true,
        node: true
      },
      parserOptions: {
        ecmaVersion: 2018
      }
    },
    rules: {
      "no-restricted-globals": ["error", "name", "length"],
      "prefer-arrow-callback": "error",
      "quotes": ["error", "double", { "allowTemplateLiterals": true }],
      "comma-dangle": ["error", "never"],
      "no-console": "warn",
      "no-debugger": "warn",
      "semi": ["error", "always"],
      "no-unused-vars": ["warn"],
      "eqeqeq": "error",
      "curly": "error"
    }
  },
  // overrides は直接配列の中に記述
  {
    files: ["**/*.spec.*"],
    env: {
      mocha: true
    },
    rules: {}
  }
];
