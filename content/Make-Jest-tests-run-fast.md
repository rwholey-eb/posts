Facebook's Jest test framework does some neat stuff like allowing mocks to be injected transparently via the CommonJS module system, and automatically generating those mocks. However, it has gotten a bit of a poor reputation for slow test execution speed. Writing tests in particular is a highly iterative task, and anything which reduces the tightness of the feedback loop between making a change and getting a red/green response adds pain and frustration to the process.

However, Jest can be quite fast, provided that it is configured with a bit of care to prevent slowness from creeping in. Jest can be fast, but there are many factors which can make its caching and performance features ineffective. Here are a few config changes I identified while fixing the performance of our Jest tests at [Culture Amp](https://www.cultureamp.com/):

## Configure a custom cache directory location

By default Jest will put all of its cache data in a directory inside the `jest-cli` package within the `node_modules` directory. This is probably okay, unless your workflow involves regularly clearing out the `node_modules` directory (eg. when changing branches and running `npm install`). In that case the cache is being thrown away, contributing to a slower startup on the next run.

## Limit the scope of Jest's file discovery

In our case, Jest is running inside a Rails app repo, with a lot of junk in it that Jest doesn't need to know about. For example, the output files from webpack, and the cache files various tools live under `tmp`. Explicitly excluding this directory reduces the files to be initially discovered.

Additionally, all the Javascript we're interested in testing resides in a couple of subdirectories – `app/client` and `lib/client`. By scoping the search for test files to these directories, and ignoring directories with a bunch of unrelated files, the startup time is further improved.

```json
  "modulePathIgnorePatterns": [
    "<rootDir>/tmp"
  ],
  "testPathDirs": [
    "<rootDir>/app/client",
    "<rootDir>/lib/client"
  ],
```

Finally, if all of your testable JS lives in a subdirectory of your project repo, make sure you set a custom `rootDir`, to further scope Jest's file-finding.

## Use persistModuleRegistryBetweenSpecs

Jest has an undocumented config option called `persistModuleRegistryBetweenSpecs`, which skips reloading the module registry between individual test cases (`it` blocks) in a test file. If you write your tests in the Jasmine/RSpec style where a seperate `it` block is used for each assertion, this can make a huge improvement to test run time, as the time spent reloading all those modules between each testcase adds up fast.

An important thing to note about changing this setting is that it might require adjusting your tests slightly. As modules will now be only reloaded once at the start of each test file, if a test makes assertions on the number of times a mock function was called, or asserts on a specifically numbered mock call, you'll need to add a call to eg. `yourMockFunction.mockClear()` in the `beforeEach` block for the test, to make sure that the relevent mock is reset between testcases.

## Use compiled versions of big dependencies

React is an example of a library which is commonly used with Jest which can slow down tests due to the fact that it is relatively slow to `require`. Loading it once may take hundreds of milliseconds, but it adds up, especially as Jest (with default settings) reloads all dependencies for every test.

Jest doesn't really come with a simple way of globally replacing certain modules, but I've determined a couple of ways to achieve it. The first (hacky and gross) solution is to use a [regexp replace in the preprocessor](https://github.com/facebook/react/pull/4656/files). But let's not do that. Instead, I've extended the default `HasteModuleLoader` to allow aliasing some modules at `require` time. I've published a small module to npm as [jest-alias-module-loader](https://www.npmjs.com/package/jest-alias-module-loader) so others can make use of it easily.

```js
// test/aliasedModuleLoader.js

var JestAliasModuleLoader = require('jest-alias-module-loader');

module.exports = JestAliasModuleLoader({
   aliasedModules: {
    // use compiled react for faster loading
    'react': 'react/dist/react-with-addons',
    'react/addons': 'react/dist/react-with-addons',
  },
});
```

To use this, just add a line to your Jest config:

```
  "moduleLoader": "<rootDir>/test/aliasedModuleLoader.js",
```

In future, I'm planning to implement a replacement for Jest's default `HasteModuleLoader` (which was primarily built to deal with Facebook's own `@providesModule` module format), to instead use the browserify project's `module-deps` library for fast, cached module resolution, using a similar caching mechanism to [browserify-incremental](https://github.com/jsdf/browserify-incremental).

## The result

By making the changes described above, our total time for running 40 tests went from 30s to 7s and the slowest individual test went from 12s to 1.7s, which is a pretty decent improvement.
