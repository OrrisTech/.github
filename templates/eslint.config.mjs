import js from "@eslint/js";
import tseslint from "typescript-eslint";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import next from "@next/eslint-plugin-next";

export default tseslint.config(
  // Global ignores
  {
    ignores: [".next/**", "node_modules/**", "dist/**", "coverage/**", "*.config.*"],
  },

  // Base JS recommended rules
  js.configs.recommended,

  // TypeScript strict rules
  ...tseslint.configs.strict,
  ...tseslint.configs.stylistic,

  // React and Next.js rules
  {
    files: ["**/*.{ts,tsx,js,jsx}"],
    plugins: {
      react,
      "react-hooks": reactHooks,
      "@next/next": next,
    },
    languageOptions: {
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
    },
    settings: {
      react: {
        version: "detect",
      },
    },
    rules: {
      // TypeScript
      "@typescript-eslint/no-unused-vars": [
        "warn",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      "@typescript-eslint/consistent-type-imports": [
        "warn",
        { prefer: "type-imports" },
      ],
      "@typescript-eslint/no-empty-interface": "off",

      // React
      "react/jsx-no-target-blank": "error",
      "react/self-closing-comp": "warn",
      "react/jsx-boolean-value": ["warn", "never"],
      "react/jsx-curly-brace-presence": ["warn", { props: "never", children: "never" }],

      // React Hooks
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",

      // Next.js
      "@next/next/no-html-link-for-pages": "error",
      "@next/next/no-img-element": "warn",

      // General
      "no-console": ["warn", { allow: ["warn", "error"] }],
      "prefer-const": "warn",
      "no-var": "error",
      eqeqeq: ["error", "always"],
    },
  }
);
