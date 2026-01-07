
import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import copy from 'rollup-plugin-copy';

export default {
  input: './dist/out-tsc/index.js',
  output: {
    dir: 'dist',
    format: 'esm',
    sourcemap: true
  },
  plugins: [
    resolve({ browser: true }),
    commonjs(),
    copy({
      targets: [
        { src: 'index.html', dest: 'dist' },
        { src: 'metadata.json', dest: 'dist' },
        { src: 'src/assets/*', dest: 'dist/assets' } // Assuming you might have assets
      ]
    })
  ]
};