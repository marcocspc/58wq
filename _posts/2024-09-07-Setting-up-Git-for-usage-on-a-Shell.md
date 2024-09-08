---
layout: post
title:  "Setting up Git for usage on a-Shell"
date:  2024-09-07 20:07:48 -0300 
categories: english ios ashell
---

# Setting up Git for usage on a-Shell 

One of the best apps I use on iPadOS is [a-Shell](https://holzschu.github.io/a-Shell_iOS/). I always tried to use it with git, since I like more doing things in the command line than while doing them via [Working Copy](https://workingcopy.app/). Since a-Shell doesn't use the standard Git implementation, I had to perform some modifications to a normal git workflow in order to use it. So here are the steps I took to clone a Github repository. 

## The .profile file

First thing I had to do was to kinda "replace" the lg2 command. As we use the [.init](https://github.com/holzschu/a-shell/issues/702) file to run commands on the application's startup, I've just added an alias command to the file, like the following:

```
alias git="lg2"
```

The thing is that even by using git instead of lg2, this open source implementation works very differently from the regular git.

For instance, when setting a custom path to my Github's ssh key in general I use the GIT_SSH_COMMAND variable, but that isn't picked automagically by lg2. By reading a lot [here](https://forum.obsidian.md/t/mobile-automatic-sync-with-github-on-ios-for-free-via-a-shell/46150/39?page=2), I was able to figure out the steps (yes, plural) needed to clone a Github repository using my own key.

## Setting up the private and public keys

So one of the things I do when storing my SSH keys is: I store only the private keys. In general, only these are needed. That's not the case, unfortunately, with lg2. 

When trying to clone the repository for this blog, for instance, I had to generate the public key from my private one in order to make it work.

With that information in mind, I had to perform [the following command](https://serverfault.com/questions/52285/create-a-public-ssh-key-from-the-private-key) to generate the public counterpart:

```
ssh-keygen -f ~/Documents/ssh-keys/github.key -y > ~/Documents/ssh-keys/github.key.pub
```

## Cloning a repository

To clone a repository from Github, we need to instantiate a git repository. Yeah, I know. So in this document I'll be using [this blog's repository](https://github.com/marcocspc/58wq) as an example.

First I had to create an empty folder and enter it:
```
mkdir 58wq && cd 58wq
```

Then init the repository (please do not give up, it's gonna work in the end I promise LOL):
```
git init
```

Then set a few configuration parameters:
```
git config user.password ""
git config user.identityFile ~/Documents/ssh-keys/github.key
git config user.name my-name
git config user.email a.valid@email
```

Set the remote URL (I got it from Github's "Code" button under the SSH tab):
```
git remote add origin git@github.com:marcocspc/58wq.git
```

Finally, "clone" the repository:
```
git pull
```

Now I could add this post to my blog. ^^

## A few observations

The following doesn't work:
```
git commit -a -m "something"
```

I need to (every time I perform a new commit):
```
git add * #or git add filename
git commit -m "something"
```

That should be it!
