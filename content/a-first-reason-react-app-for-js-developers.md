We're going to build a small single page web app to put Reason React through its paces. The app will display a list of top Reason-related Github repos, which can be clicked into to view more details. It's a small enough task that we can complete it in a few hours, but also has enough complexity that we can kick the tires of this new language.

### Before we get started

Make sure you have your editor set up for Reason. You're not getting the full benefit of a statically typed language if you haven't got type information, inline errors and autocomplete in your editor. For a quick editor setup, I can recommend [Atom packages described on the Reason website]a(http://facebook.github.io/reason/tools.html#editor-integration-atom), with the addition of my package [linter-refmt](https://atom.io/packages/linter-refmt) which integrates much better syntax error messages with Atom. Without this, you'll have to look at the compiler console output to debug some syntax errors.

If you haven't done so, you probably also need to install the Reason CLI tools.

**There is a newly released version of the Reason CLI tools which is required to use this tutorial.**

You can find install instructions [here](https://github.com/reasonml/reason-cli#1-install-reason-cli-globally). If you are on macOS and have npm, all you need to do to install the tools is:

```bash
npm install -g https://github.com/reasonml/reason-cli/archive/beta-v-1.13.6-bin-darwin.tar.gz
```

### A new project

We're going to use [create-reason-react-app](https://github.com/knowbody/crra), which will create a starting point for our app:

```bash
npm install -g create-reason-react-app
create-reason-react-app github-reason-list
cd github-reason-list
# install dependencies: the reason-to-js compiler (bucklescript), webpack, react and more
npm install
# starts 'bsb' which compiles reason to js, and also webpack-dev-server, in parallel
npm start
```

If you're using [yarn](yarnpkg.com) you can instead do:

```bash
yarn create reason-react-app github-reason-list
cd github-reason-list
yarn install
yarn start
```

I'll go into more detail about what's going on under the hood later, right now we just want to get something on the screen.

Open http://localhost:8080 and you should see this:

![Screenshot of Create Reason React App blank slate](/files/crra.png)

This page is being rendered using React, from a component written in Reason. In your editor, open the project folder and open up `src/index.re`. If you've built many React apps this should look pretty familiar. The Reason code:

```reason
ReactDOMRe.renderToElementWithId <App name="Welcome to Create Reason React App!" /> "root";
```

is doing roughly the same thing as this Javascript equivalent:

```js
ReactDOM.render(<App name="Welcome to Create Reason React App!" />, document.getElementById('root'));
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

Let's move over to `src/app.re`. Don't worry too much about all the stuff going on here, we'll go through the pieces one by one as we need them.

Let's start making some changes. We're going to start building the front page of our app, starting with the render method of our top level component. Replace the entire contents of the file with:

```reason
let component = ReasonReact.statelessComponent "App";

let make ::name _children => {
  ...component,
  render: fun () self =>
    <div className="App">
      <div className="App-header">
        <h1> (ReactRe.stringToElement "Reason Projects") </h1>
      </div>
    </div>
};
```

Hit save and jump back to your browser window showing [http://localhost:8080](http://localhost:8080). You should see a page which just says 'Reason Projects'. Jump back to your editor and let's walk through this code, which looks somewhat like the JSX you're used to, but not quite.

In Reason React, some things are a bit more explicit than normal Javascript React. Reason's JSX doesn't allow you to display text by simply putting it directly between JSX tags. Instead we use a function called `ReactRe.stringToElement`, and we call it with the string of text we want to display: `"Reason Projects"`. In Reason strings are always double quoted. Finally, we wrap it in parens so that Reason knows that `"Reason Projects"` is an argument to `ReactRe.stringToElement`, but the following `</h1>` is not.

You can think of the above code as being more or less equivalent to this JS React code:

```js
class App extends React.Component {
  render() {
    return ( 
      <div className="App">
        <div className="App-header">
          <h1>{'Reason Projects'}</h1>
        </div>
      </div>
    );
  }
}
```

If you don't see any change, it's possible that you have a syntax error. Errors won't show in the browser, just in the editor and `yarn start`/`npm start` command output.

<aside>
Debugging syntax errors

If you're new to Reason, it can be a bit difficult to spot where exactly you've made a syntax error. This is especially true with some of the current editor integrations, because they sometimes display an error further down in the file than where the incorrect piece of syntax is.

If the first error message in the file is 'Invalid token', you're dealing with a syntax error. If take a look at the terminal output of the `yarn start`/`npm start` command you should see a more helpful error message, including the file, line, and character position of the error. As Reason editor integration improves this should no longer be necessary.
</aside>

### A record type

Next, our list of repos. First we'll build out the UI components with fake data, and then replace it with data from this API request:
https://api.github.com/search/repositories?q=topic%3Areasonml&type=Repositories

We'll define a record type to represent each repo item from the JSON. A record is like a JS object, except the properties it has and their types are fixed. Defining a record type for our Github repos looks like this:

```reason
type repo = {
  full_name: string,
  stargazers_count: int,
  html_url: string
};
```

Create a new file called `RepoData.re` and add the above code into it.

<aside>
Files are modules

We've defined our type at the top level of the file. In Reason, every file is a module, and all the things defined at the top level of the file using the keywords `let`, `type`, and `module` are exposed to be used from other files (that is, other modules). In this case, other modules can reference our `repo` type as `RepoData.repo`. Unlike in Javascript, no imports are required to reference things from other modules.
</aside>

Let's use our type in `app.re`. The repos page is just a list of repos, with each item in the list consisting of the name of the repo (linking to the repo on Github), and the number of stars the repo has. We'll define some dummy data and sketch out a new component called `RepoItem` to represent an item in the list of repos:

```reason
let component = ReasonReact.statelessComponent "App";

let make ::title _children => {
  ...component,
  render: fun () self => {
    let someRepo: RepoData.repo = {
      stargazers_count: 27,
      full_name: "jsdf/reason-react-hacker-news",
      html_url: "https://github.com/jsdf/reason-react-hacker-news"
    };
    <div className="App">
      <div className="App-header"> <h1> (ReactRe.stringToElement "Reason Projects") </h1> </div>
      <RepoItem repo=someRepo />
    </div>
  }
};
```

In the statement beginning `let aRepo: RepoData.repo =`, `aRepo` is the name of the constant we're defining and `RepoData.repo` is the type we're annotating it with. Reason can infer the types of most things we declare, but here it's useful to include the annotation so that the typechecker can let us know if we've made a mistake in our test data.

<aside>
Return values in Reason

Note that the body of the render function is now wrapped in `{}` braces. In Javascript, if we used braces around the body of an `=>` arrow function we'd need to add a `return` statement to return a value. However in Reason, value resulting from the last statement in the function automatically becomes the return value. If you don't want to return anything from a function, you can make the last statement `()`.
</aside>

### A stateless React component

You might now see an error saying 'unbound module RepoItem'. That's because we haven't created that module yet. We'll add the new file called `RepoItem.re`:

```reason
let component = ReasonReact.statelessComponent "RepoItem";

let make repo::(repo: RepoData.repo) _children => {
  ...component,
  render: fun () self =>
    <div className="RepoItem" />
};
```

Here we have a minimal stateless component which takes one prop called `repo`. Each Reason React component is a Reason module which defines a function called `make`. This function returns a record, and merges in the return value of `ReasonReact.statefulComponent` or `ReasonReact.statelessComponent` (for components which do and don't use state, respectively). If this seems a bit weird, just think of if like `class Foo extends React.Component` in JS React.

Next we'll flesh out the render method to present the fields of the `repo` record:

```reason
let component = ReasonReact.statelessComponent "RepoItem";

let make repo::(repo: RepoData.repo) _children => {
  ...component,
  render: fun () self =>
    <div className="RepoItem">
      <a href=repo.html_url> <h2> (ReactRe.stringToElement repo.full_name) </h2> </a>
      (ReactRe.stringToElement (string_of_int repo.stargazers_count ^ " stars"))
    </div>
};
```

Now is a good time to save and take a look at our progress in the browser.

Note that we convert the int value of `repo.stargazers_count` to a string using the `string_of_int` function, before concatenating it with the string `" stars"` with the `^` string concatenation operator.

In JS React we define a `render` method on a class, and inside it we can access `this.props`, which is an instance property of the component class instance. In Reason React we recieve the props as labeled arguments to `make` (the weird `::` syntax signified labeled arguments), and `render` is just a function defined inside `make`, and returned as part of the record returned from `make`.

### BuckleScript

Before fetching our JSON and turning it into a record, first we need to install some extra dependencies. Run:

```bash
npm install --save buckletypes/bs-fetch buckletypes/bs-json
```

Here's what these packages do:
- buckletypes/bs-fetch: wraps the browser Fetch API so we can use it from Reason
- buckletypes/bs-json: allows use to turn JSON fetched from the server into Reason records

These packages work with the Reason-to-JS compiler we've been using this whole time, which is called BuckleScript.

Before we can use these newly installed BuckleScript packages we need to let BuckleScript know about them. To do that we need to make some changes to the .bsconfig file in the root of our project. In the `bs-dependencies` section, add `"bs-fetch"` and `"bs-json"`:

```json
{
  "name": "create-reason-react-app",
  "reason": {
    "react-jsx": 2
  },
  "bs-dependencies": [
    "reason-react",
    "bs-director",
    "bs-fetch", // add this
    "bs-json" // and this too
  ],
  // ...more stuff
```

You'll need to kill and restart your `yarn start`/`npm start` command so that the build system can pick up the changes to `.bsconfig`.

### Reading JSON

Now we've installed `bs-json` we can use `Json.Decode` to read JSON and turn it into a record.

We'll define a function called `parseRepoJson` at the end of `RepoData.re`:
```reason
type repo = {
  full_name: string,
  stargazers_count: int,
  html_url: string
};

let parseRepoJson json :repo => {
  full_name: Json.Decode.field "full_name" Json.Decode.string json,
  stargazers_count: Json.Decode.field "stargazers_count" Json.Decode.int json,
  html_url: Json.Decode.field "html_url" Json.Decode.string json
};
```

This defines a function called `parseRepoJson` which takes one argument called `json` and returns a value of the type `RepoData.repo`. The `Json.Decode` module provides a bunch of functions which we are composing together to extract the fields of the JSON, and assert that the values we're getting are of the correct type.

However, it's looking a bit wordy. Do we really have to write `Json.Decode` over and over again?

Nope, Reason has some handy syntax to help us when we need to refer to the exports of a particular module over and over again. One option is to 'open' the module, which means that all of its exports become available in the current scope, so we can ditch the `Json.Decode` qualifier:

```reason
let parseRepoJson json :repo => Json.Decode.{
  full_name: field "full_name" string json,
  stargazers_count: field "stargazers_count" int json,
  html_url: field "html_url" string json
};
```

Now let's test it out by adding some code which defines a string of JSON and uses our `parseRepoJson` function to parse it.

In `app.re`: 
```reason
render: fun () self => {
  let someRepo =
    RepoData.parseRepoJson (
      Js.Json.parseExn {js|
    {
      "stargazers_count": 93,
      "full_name": "reasonml/reason-tools",
      "html_url": "https://github.com/reasonml/reason-tools"
    }
  |js}
    );
  <div className="App">
    <div className="App-header"> <h1> (ReactRe.stringToElement "Reason Projects") </h1> </div>
    <RepoItem repo=someRepo />
  </div>
}
```

Don't worry about understanding what `Js.Json.parseExn` does or the weird `{js| |js}` thing (it's an alternative [string literal syntax which doesn't require escaping quotes](http://bucklescript.github.io/bucklescript/Manual.html#_bucklescript_annotations_for_unicode_and_js_ffi_support)). Returning to the browser you should see the page sucessfully render from this JSON input.

### Fetching data

```reason
let reposUrl = "https://api.github.com/search/repositories?q=topic%3Areasonml&type=Repositories";

let parseReposJsonText jsonText =>
  Js.Promise.resolve (parseRepos (Js.Json.parseExn jsonText))

let fetchRepos () =>
  Bs_fetch.fetch (reposUrl id)
    |> Js.Promise.then_ Bs_fetch.Response.text
    |> Js.Promise.then_ (fun jsonText =>
      jsonText
        |> Js.Json.parseExn
        |> parseRepos
        |> Js.Promise.resolve);

fetchRepos ()
  |> Js.Promise.then_ (fun repos => {
      setState prevState => {...prevState, repos}
      Js.Promise.resolve ()
    })
```


### Option and pattern matching

Now lets say we want to add the `homepage` field to our `repo` type, which can contain a link to a website about the project. Unlike the other fields in our record, this one can be `null` in the JSON we get back from the API. However, in Reason you can't just have the value of a string field be `null`, as you can in Javascript. Instead, things which might not be present need to be wrapped in another type called `option`. We can add the field to our `repo` type in `RepoData.re` like so: 

```reason
type repo = {
  full_name: string,
  stargazers_count: int,
  html_url: string,
  homepage: option string
};
```

Now in `app.re` we'll update our test data:
```reason
let someRepo: RepoData.repo = {
  stargazers_count: 27,
  full_name: "jsdf/reason-react-hacker-news",
  html_url: "https://github.com/jsdf/reason-react-hacker-news",
  homepage: Some "https://jamesfriend.com.au"
};
```

The word `Some` above is a thing called a 'type constructor', and it is 'wrapping' or 'containing' the url string value which follows it. The url string is a 'parameter' to the type constructor. If this seems confusing, just think of this as a way to have a place which can be occupied by one of a few different kinds of data. In this case a `Some` value containing our string. If the repo in question had no homepage, we would instead represent it as: 

```reason
let someRepo: RepoData.repo = {
  stargazers_count: 27,
  full_name: "jsdf/reason-react-hacker-news",
  html_url: "https://github.com/jsdf/reason-react-hacker-news",
  homepage: None
};
```
As you can see, a `None` value doesn't take a parameter (which makes sense, because it doesn't contain anything).

Jumping over to `RepoItem.re`, we can try to use our new field:

```reason
let component = ReasonReact.statelessComponent "RepoItem";

let make repo::(repo: RepoData.repo) _children => {
  ...component,
  render: fun () self =>
    <div className="RepoItem">
      <a href=repo.html_url> <h2> (ReactRe.stringToElement repo.full_name) </h2> </a>
      (ReactRe.stringToElement (string_of_int repo.stargazers_count ^ " stars"))
      <a href=repo.homepage> (ReactRe.stringToElement "Homepage") </a>
    </div>
};
```

After typing this out and saving the file you should see an error pointing to `repo.homepage` which says something like:

```
Error: The types don't match.
This is: option string
Wanted:  string
```

This is because we can't just render our option-typed value, because it might not be present (in other words, it might be `None`). Instead we have to provide code to handle both the case when it is `Some` and `None`. We can do this with **pattern matching**, which basically just means a `switch` statement which handles the different possible values of `repo.homepage`. Unlike a switch statement in Javascript however, a switch statement in Reason matches the *types* of the values, not just the values themselves. Change the render function to be:

```reason
render: fun () self => {
  let homepageLink =
    switch repo.homepage {
    | Some url => <a href=url> (ReactRe.stringToElement "Homepage") </a>
    | None => ReactRe.stringToElement "no homepage"
    };

  <div className="RepoItem">
    <a href=repo.html_url> <h2> (ReactRe.stringToElement repo.full_name) </h2> </a>
    (ReactRe.stringToElement (string_of_int repo.stargazers_count ^ " stars"))
    homepageLink
  </div>
}
```

Here you can see the switch statement has a case to match a `repo.homepage` value with the type `Some`, and pulls out the homepage url string into a variable called `url`, which it then uses in the expression to the right of the `=>`, which creates an `<a>` tag. This expression will only be used in the `Some` case. Alternatively, if `repo.homepage` is `None`, the text "no homepage" will be displayed instead.

Now we've worked out how to define a record of data and use it to render stuff, let's replace our dummy data with the real thing.
