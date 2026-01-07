
import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import typescript from '@rollup/plugin-typescript';
import copy from 'rollup-plugin-copy';

export default {
  input: 'index.tsx',
  output: {
    dir: 'dist',
    format: 'esm',
    sourcemap: true
  },
  plugins: [
    resolve({ browser: true }),
    commonjs(),
    typescript({
      tsconfig: './tsconfig.app.json'
    }),
    copy({
      targets: [
        { src: 'index.html', dest: 'dist' },
        { src: 'metadata.json', dest: 'dist' },
        { src: 'assets/*', dest: 'dist/assets' } // Assuming you might have assets
      ]
    })
  ]
};
