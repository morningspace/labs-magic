# Learning basics

Termitorial can parse a Markdown file and print text, execute shell scripts or commands line by line.
This lesson will show you how to write your Markdown file to make it happens.

## Title and text

Just as Markdown syntax defines, the line prefixed with one or more `#` chars will be interpreted as title.
Other lines without leading `#` char will be interpreted as normal text.

Multiple lines of normal text ended with newline will be interpreted as a paragraph. The first paragraph in
the Markdown file will be treated as the excerpt of this lesson and printed in different color.

For each newline, there will be a pause with a message displayed as "Press Enter key to continue...".

## Shell code

To run shell code, you can place the code snippet inside a code block surrounded with triple backticks with
the leading triple backticks appended with `shell`.

Fo example, let's list all contents under your $HOME directory:
```shell
ls -1 $HOME
```

If there is no `shell` hint added after the leading triple backticks, then the code will not be interpreted
as excutable but will be displayed directly.

For example, the output of above `ls` command will be something similar as below:
```
$ ls -1 $HOME
Applications
Desktop
Documents
Downloads
Library
Movies
Music
Pictures
Public
```

## Run custom shell function

You can also define your own shell function which can be invoked in shell code block. As an example, please
refer to [helper.sh](../helper.sh) where it includes a custom shell function as below:
```shell
sum 2 3
```
