Apparently [Hacker News Progressive Web Apps are the new TodoMVC](https://hnpwa.com) according to Addy Osmani, so let's build one to put Reason React through its paces. It's a small enough task that we can complete it in a few hours, but also has enough complexity that we can kick the tires of this new language with some realistic challenges.

### Before we get started

Make sure you have your editor set up for Reason. You're not getting the full benefit of a statically typed language if you haven't got type information, inline errors and autocomplete in your editor. For a quick editor setup, I can recommend Atom + the Nuclide package, or Visual Studio Code + the Reason package. However neither of these are perfect (which I'll come back to in the 'Locating syntax errors' section below).

If you haven't done so, you probably also need to [install the Reason CLI tools](https://facebook.github.io/reason/jsWorkflow.html#javascript-workflow-editor-setup-global-utilities).

### A new project

We're going to use [create-reason-react-app](https://github.com/knowbody/crra), which will create a starting point for our app:

With Yarn

```bash
yarn create reason-react-app reason-hn
cd reason-hn
# install dependencies: the reason-to-js compiler (bucklescript), webpack, react and more
yarn install
# starts 'bsb' which compiles reason to js, and also webpack-dev-server, in parallel
yarn start
```

With npm

```bash
npm install -g create-reason-react-app
create-reason-react-app reason-hn
cd reason-hn
# install dependencies: the reason-to-js compiler (bucklescript), webpack, react and more
npm install
# starts 'bsb' which compiles reason to js, and also webpack-dev-server, in parallel
npm start
```

I'll go into more detail about what's going on under the hood later, right now we just want to get something on the screen.

Open http://localhost:8080 and you should see this:

![Screenshot of Create Reason React App blank slate](/files/crra.png)

This page is being rendered using React, from a component written in Reason. In your editor, open the project folder and open up `src/index.re`. If you've built many React apps this should look pretty familiar. The Reason code:

```reason
ReactDOMRe.renderToElementWithId <App title="Welcome to Create Reason React App!" /> "root";
```

is doing roughly the same thing as this Javascript equivalent:

```js
ReactDOM.render(<App title="Welcome to Create Reason React App!" />, document.getElementById('root'));
```

<aside>
  ### Function calls in Reason

  When comparing the Reason and Javascript code above, you'll notice that the Reason version omits the parentheses `()` around the function call, and also the commas between the arguments. In Reason, each space-separated value after the function name is an argument to the function. Parentheses are only needed if you want to call one function and use the result as an argument to another function, eg.

  ```reason
  myFunctionB (myFunctionA arg1 arg2) arg3
  ```

  which is equivalent to this Javascript:

  ```js
  myFunctionB(myFunctionA(arg1, arg2), arg3)
  ```
</aside>

### JSX in Reason

Let's move over to `src/app.re`. You might notice this looks a bit like a sort of uncanny valley version of a React component class. Don't worry too much about all the stuff going on here, we'll go through the pieces one by one as we need them.

Let's start making some changes. We're going to start building the front page of our app, starting with the render method of our top level component. Replace everything from `let render` to `</div>;` with
```reason
 let render _ =>
    <div className="App">
      <div className="App-header">
        <h1> (ReactRe.stringToElement "Reason React Hacker News") </h1>
      </div>
    </div>;
```

In Reason React, some things are a bit more explicit than normal Javascript React. Reason's JSX doesn't support displaying text by simply putting it directly between JSX tags, instead we use a function called `ReactRe.stringToElement` and pass it a string of the text we want to display: `"Reason React Hacker News"`. In Reason strings are always double quoted. Finally, we wrap it in parens so that Reason knows that `"Reason React Hacker News"` is an argument to `ReactRe.stringToElement`, but the following `</h1>` is not.

You can think of the above code as being equivalent to this Javascript JSX:

```js
render() {
  return ( 
    <div className="App">
      <div className="App-header">
        <h1>{'Reason React Hacker News'}</h1>
      </div>
    </div>
  );
}
```

Save your changes. Now, take a look in your browser. You should see this:

![Screenshot with Header only](/files/hn-re-header.png)

If you don't see any change, it's possible that you have a syntax error. Errors won't show in the browser, just in the editor and `yarn start`/`npm start` command output.

<aside>
Debugging syntax errors

If you're new to Reason, it can be a bit difficult to spot where exactly you've made a syntax error. This is especially true with the current editor integrations for Atom and VS Code, because they sometimes display an error further down in the file than where the incorrect piece of syntax is.

If the first error message in the file is 'Invalid token', you're dealing with a syntax error somewhere prior to that location. You can take a look at the terminal output of the `yarn start`/`npm start` command to find where exactly the error is. Scroll back through the output until you see something like `<SYNTAX ERROR>`. On the preceeding line there will be a file, line and character position, which should be the location of the actual syntax error. As Reason editor integration improves this should no longer be necessary.
</aside>

### A record type

Next, the Top Stories page. First we'll build out the UI components with fake data, and then replace it with data from this API endpoint:
http://serverless-api.hackernewsmobile.com/topstories.json

We'll define a record type to represent each top story item from the JSON. We add a new file called `StoryData.re`:

```reason
type topstory = {
  by: string,
  descendants: int,
  id: int,
  score: int,
  time: int,
  title: string,
  url: string
};
```

<aside>
Files are modules

We've defined our type at the top level of the file. In Reason, every file is a module, and all the things defined at the top level of the file using the keywords `let`, `type`, and `module` are exposed to be used from other files (that is, other modules). In this case, other modules can reference our `topstory` type as `StoryData.topstory`. Unlike in Javascript, no imports are required to reference things from other modules.
</aside>

Let's use our type in `app.re`. The top stories page is just a list of top stories, with each containing a title (which links to the article), the number of points the article has, the submitter's username, time since submitted, the number of comments (which links to the comments page). To get started on implementing it, we'll define some dummy data and sketch out a new component called `TopStoriesItem` to represent an item in the list of stories,

```reason
let render _ => {
  let aTopStory: StoryData.topstory = {
    by: "mozillas",
    descendants: 13,
    id: 14483429,
    score: 94,
    time: 1496609490,
    title: "FlexBox Cheatsheet",
    url: "http://vudav.github.io/flexbox-cheatsheet/"
  };

  <div className="App">
    <div className="App-header">
      <h1> (ReactRe.stringToElement "Reason React Hacker News") </h1>
    </div>
    <TopStoriesItem topstory=aTopStory />
  </div>
};
```

In the statement beginning `let aTopStory: StoryData.topstory =`, `aTopStory` is the name of the constant we're defining and `StoryData.topstory` is the type we're annotating it with. Reason can infer the types of most things we declare, but here it's useful to include the annotation so that the typechecker can let us know if we've made a mistake in our test data.

<aside>
Return values in Reason

Note that the body of the render function is now wrapped in `{}` braces. In Javascript, if we used braces around the body of an `=>` arrow function we'd need to add a `return` statement to return a value. However in Reason, value resulting from the last statement in the function automatically becomes the return value. If you don't want to return anything from a function, you can make the last statement `()`.
</aside>

### A stateless React component

Now we need to implement TopStoriesItem. We'll add the new file called `TopStoriesItem.re`:

```reason
module TopStoriesItem = {
  include ReactRe.Component;
  type props = {topstory: StoryData.topstory};
  let name = "TopStoriesItem";
  let render _ => <div className="TopStoriesItem-root" />;
};

include ReactRe.CreateComponent TopStoriesItem;

let createElement ::topstory => wrapProps {topstory: topstory};
```

Here we have a minimal stateless component which takes one prop called `topstory`. Each Reason React component defines a module using the `module` keyword, which contains a definition of a type called `props`, a string constant `name` which defines the name of the component in the React Devtools, and a `render` function. At the end of the file we also need to define a `createElement` function to map named arguments (denoted by `::`) to the fields of the props record.

Next we'll flesh out the render method to present the fields of the `topstory` record:

```reason
let render {props} => {
  let {topstory} = props;
  <div className="TopStoriesItem-root">
    <a href=topstory.url> (ReactRe.stringToElement topstory.title) </a>
    (ReactRe.stringToElement ((string_of_int topstory.score) ^ " points"))
    (ReactRe.stringToElement ("by " ^ topstory.by))
  </div>
};
```

Now is a good time to save and take a look at our progress in the browser.

Note that we convert the int value of `topstory.score` to a string using the `string_of_int` function, before concatenating it with the string `" points"` with the `^` string concatenation operator.

In JS React we define a `render` method on a class, and inside it we can access `this.props`, which is an instance property of the component class instance. In Reason React `render` is just a function, and as its first argument we receive a record including the props and a bunch of other stuff (referred to in the Reason React docs as the `ComponentBag`. In the example above, we are using record destructuring to extract the `props` field of the record.

<aside>
More ways to `render`
  
We could alternatively just give the first argument to `render` a name. Then we could pass it around or access its fields as required. If we wanted to be really cute we could call it `this`:

```reason
let render this => {
  let {topstory} = this.props;
  /* ... */
};
```

If we don't need to access `props` or anything else from the `ComponentBag` we can just name the argument `_` (underscore), which tells Reason we don't intend to use it. Unlike Javascript, in Reason if a function will be called with a certain number of postional arguments, you can't omit one from the function definition just because you don't intend to use it, which is why we need to use `_` instead:

```reason
let render _ => {
  <div />
};
```
</aside>

### Option and pattern matching

I've just noticed a problem with our `topstory` type. The `url` field isn't always present, such as in the case of text posts. However, in Reason you can't just have the value of a string field be `null`, like in Javascript. Instead, things which might not be present need to be wrapped in another type called `option`. We can change the `url` field of our `topstory` type like so: 

```reason
type topstory = {
  by: string,
  descendants: int,
  id: int,
  score: int,
  time: int,
  title: string,
  url: option string
};
```

### BuckleScript

Let's replace our dummy data with the real thing.

First we need to install some extra dependencies. Run

```bash
yarn add buckletypes/bs-fetch buckletypes/bs-json
```

We're adding a couple of modules which provide wrappers for the browser Fetch API and also for turning JSON fetched from the server into Reason records. These modules work with the Reason-to-JS compiler we've been using this whole time, which is called BuckleScript.

To use these newly installed BuckleScript packages we need to let BuckleScript know about them. To do that we need to add them to the .bsconfig file in the root of our project.

```json
{
  "name": "create-reason-react-app",
  "reason": {
    "react-jsx": true
  },
  "bs-dependencies": [
    "reason-react",
    "bs-director",
    "bs-fetch", // add this
    "bs-json" // and this too
  ],
  "sources": [
    {
      "dir": "src"
    }
  ]
}
```

You'll need to kill and restart your `yarn start`/`npm start` command so that `bsb` (the BuckleScript build system) can pick up the changes to `.bsconfig`.

### Reading JSON

Now we've installed `bs-json` we can use `Json.Decode` to read JSON and turn it into a record.

We'll start by just reading a single field from some JSON data.

In `index.re`:
```reason
type myrecord = {
  by: string,
};

let parseRecord json :myrecord =>
  {
    by: Json.Decode.field "by" Json.Decode.string json,
  };
```

This defines a function called `parseRecord` which takes one argument called `json` and returns a value of the type `myRecord`. The `Json.Decode` module provides a bunch of functions which we are composing together to extract the fields of the JSON, and assert that the values we're getting are of the correct type.


Now let's test it out by adding some code which defines a string of JSON and uses our `parseRecord` to log the value of the `by` field to the browser console. Note that I've escaped the doublequote characters in the JSON string. Reason does have [other string literal syntaxes which don't require escaping quotes](http://bucklescript.github.io/bucklescript/Manual.html#_bucklescript_annotations_for_unicode_and_js_ffi_support), but I'll leave those for another time.
```reason
let aRecordJSON = "{\"by\": \"jsdf\"}";

let aRecord = parseRecord aRecordJSON;

Js.log aRecord.by; /* prints 'jsdf' to the browser console */
```

However, it's looking a bit wordy. Do we really have to write `Json.Decode` over and over again?

Nope, Reason has some handy syntax to help us when we need to refer to the exports of a particular module over and over again. One option is to 'open' the module, which means that all of its exports become available in the current scope, so we can ditch the `Json.Decode` qualifier:

```reason
open Json.Decode;

let parseRecord json :myrecord =>
  {
    by: field "by" string json,
  };
```

However, maybe we just want to open up a module temporarily for one expression. Reason has a syntax for that too; just put the module name, followed by a `.` before the expression:

```reason
let parseRecord json :myrecord =>
  Json.Decode.{
    by: field "by" string json,
  };
```

A complete decoder function for our `StoryData.topstory` record type:

In `StoryData.re`:
```reason
let parseTopStory json :topstory =>
  Json.Decode.{
    by: field "by" string json,
    descendants: field "descendants" int json,
    id: field "id" int json,
    score: field "score" int json,
    time: field "time" int json,
    title: field "title" string json,
    url: optional (field "url" string) json
  };
```


Now let's test it out by adding some code which defines a string of JSON and uses our `parseTopStory`
```reason
let aTopStoryJSON = "{
  \"by\": \"jsdf\",
  \"descendants\": 32,
  \"id\": 123,
  \"score\": 200,
  \"time\": 1497034333,
  \"title\": \"PCE.js - classic mac emulator\",
  \"url\": \"https://jamesfriend.com.au/pce-js/\"
}";

let aTopStory = parseTopStory aTopStoryJSON;

Js.log aTopStory.by; /* prints 'jsdf' to the browser console */
```


### Fetching data



