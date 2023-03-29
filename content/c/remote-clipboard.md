---
title: 'Clipboard Sharing to a Remote Dev Environment'
date: 2023-04-06
weight: 9907
---

# Clipboard Sharing to a Remote Dev Environment

I run my development environment in portable and reproducible virtual machine
built with [nix](https://nixos.org/). Once the VM is started, accessing all my
projects is just a matter of using `ssh`, or [mosh](https://mosh.org/) depending
on what I’m feeling that day. The biggest, and perhaps only, pain point with my
approach is clipboard sharing between client (my laptop) and server (my VM). For
example, when I’m copying logs from the VM’s tmux session or copying lines in
neovim, I want to have those instantly in the clipboard of my client machine.

{{< youtube QzY8TvYAazE >}}

There are are a variety of ways to share a clipboard in popular virtual machine
applications like Fusion or Parallels. However, these approaches don’t work for
me for a few reasons:

1. It’s not portable: While I usually run my VM locally, sometimes I’ll do it in
   a cloud provider.
2. My VM does not run a desktop environment, thus there is no concept of a
   clipboard.

Like many things in software, I’ve gone searching for a solution only to come
back to a technology that’s been around since (at least) the 80s. This
technology is the named pipe. Effectively I used this persistent pipe/queue as a
pseudo clipboard to facilitate sharing and today I’m going to explain how.

This post assumes you understand how a named pipe works. But, if you don’t have
experience with named pipes, checking my post on [Pipes: Named and
Unnamed](https://joshrosso.com/c/pipes) to dig into how they work.

## Attachment

Attaching my client machine to the VM is a matter of ensuring:

1. The named pipe exists.
2. The client can “connect and listen” to the pipe.
3. When data is in the pipe, it reads it, and puts it in the guest clipboard.

Here’s a visual representation of this idea:

<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="100%" viewBox="-0.5 -0.5 661 421" content="<mxfile host=&quot;app.diagrams.net&quot; modified=&quot;2023-03-20T23:08:27.230Z&quot; agent=&quot;5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36&quot; version=&quot;21.0.8&quot; etag=&quot;OTQ2Jf5bEIeE43VdBQ-r&quot; type=&quot;device&quot;><diagram name=&quot;Page-1&quot; id=&quot;BdAfObHYoVCEQR0XW3Un&quot;>7VrLcts2FP0azTQLewCCz6UlK8kimcmMZtpmCZGQhJQiWAiypS767b0wwQdEStaDllJPvDFw8eQ59x5cwB6Q0XLzSdJ88VUkLB04KNkMyOPAcTCOXPilLVtj8X1cWOaSJ8ZWGyb8H2aMyFjXPGErq6MSIlU8t42xyDIWK8tGpRTPdreZSO1VczpnLcMkpmnb+gdP1KKwhh6q7Z8Zny/KlTEyLUtadjaG1YIm4rlhIuMBGUkhVFFabkYs1eiVuBTjPu5prTYmWaaOGeAUA55oujbfZvaltuXHSrHOEqb7owEZPi+4YpOcxrr1GfgF20ItU6hhKJrpmFRss3dLuPpQcBEmlkzJLXQxAxxisDHe4YSm/lxD7fvGtmjAXLkHNfTOq7lrBKBgQOgGhLQA+f3rZZDMeJqORCrky1gym8VxFIF9paT4izVaiE8ikugRIlMTsxq+EqLY7UDU7QFQt8PD/BQWGE6hMNeFf2GOOOV51SDLlt9gZEaXADV8L89ZuwegC1b0oWyBqap5D/CGT+YNIQ+xmWHH4lP/dPGJEH4cjvoJCuLaFJIuCp0OCv0eKPRaQLIE9NBUhVQLMRcZTce1dWiHSN3nixC5AfgHU2prxJ2ulbDhB2Dk9k89/t71y/p33XiPsFcaHjdmhaK2bda+McnhW5k0xh1C8ZRi5nQT548fPlYtpcQTPfGGq2JTnql9L/cL5Xo3ulJupkBPQ2aRvxJrGRuTbw4xKuesjL2jXUSylCr+ZM9+Cd9+K2SzJ768MJosTWuRESdsGk4PqmIPUeSRG0ZRcIsoanvwEd5YnqNNd/Rv547hjeXH8Sz5eU16zlCINkuna9WZvL6BzLwMfZCSbhsdcsEztWrM/E0b6tAMIjs03WAncd3pT4KD/aFQ7KD2sOpTjnK6aG/aopXMckf/77UoG+5WLw71AB2wm29eeCnby7RkJHKNzHjD4rXSqU2VuRRT70leNLVf6BTuUpaj0pTPMyjHwJ8+6oZaITncVR5Mw5InSRETDDZHpy/zaa8zlMDk3nDgPR6SWHORMoMH1fWl6TbhQem9g2PcDTyLsztz2TjNs1qucBfas4b2BGI2W4G37wrOae5Qhk7DH9RyvXkHZ2JwyzMR4xaC19V2S9prMe+W9vMOU9IWXdwRPtc6TXH7hn8NyKtT0Tn+WNyJB+bBJRV1xcPQQQj1ytANs2/cfoJo3ZhXq8WbX3ivIz+u+/rbhOt6bfkhXg9Qdz1O/GTPX8GRr1+4Fz32WoCMUq53/s6ewDpQfbMXMOzf+JALwqB5zEEqhtzwnBeU8+Q17DgAyQ31Ndirr0en9v6e1H4y+QzNoyJb5iJ7L7l94cJ7owty+yDsKZkPdiKun/Q9bHFOUxpLDhHU8eoMYC85BNuHCw/UnzG/x/ia+X10C+m7Ut54AhcXBoWHontMkEt0mPko3LlHQ850Xzf6UUDsBQrlNXNeFEdO+xr8Sztf087oFe1EEfLtEO1XSbc2d70Ka7mthkOkfKVYBpADS6Cw+aHc8f8ioq53PRGFav33/4KS+t8oyPg/</diagram></mxfile>" style="background-color: rgb(255, 255, 255);"><defs></defs><g><rect x="0" y="210" width="660" height="210" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><rect x="0" y="210" width="140" height="40" fill="#ffcc99" stroke="#36393d" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 138px; height: 1px; padding-top: 230px; margin-left: 1px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; font-weight: bold; white-space: normal; overflow-wrap: normal;">VM</div></div></div></foreignObject><text x="70" y="234" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle" font-weight="bold">VM</text></switch></g><rect x="110" y="310" width="120" height="60" rx="9" ry="9" fill="#0050ef" stroke="#001dbc" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 340px; margin-left: 111px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>~/clip<br>( named pipe<br>file )</b></div></div></div></foreignObject><text x="170" y="344" fill="#ffffff" font-family="jbm" font-size="12px" text-anchor="middle">~/clip...</text></switch></g><path d="M 360 370 L 360 390 L 165.2 390 L 165.2 381" fill="none" stroke="#006eaf" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 165.2 374.25 L 169.7 383.25 L 165.2 381 L 160.7 383.25 Z" fill="#006eaf" stroke="#006eaf" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><rect x="300" y="310" width="120" height="60" rx="9" ry="9" fill="#cdeb8b" stroke="#36393d" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 340px; margin-left: 301px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; font-weight: bold; white-space: normal; overflow-wrap: normal;">nvim</div></div></div></foreignObject><text x="360" y="344" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle" font-weight="bold">nvim</text></switch></g><path d="M 500 340 L 430.1 340" fill="none" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 423.35 340 L 432.35 335.5 L 430.1 340 L 432.35 344.5 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><path d="M 560 370 L 560 400 L 140 400 L 140 380.1" fill="none" stroke="#006eaf" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 140 373.35 L 144.5 382.35 L 140 380.1 L 135.5 382.35 Z" fill="#006eaf" stroke="#006eaf" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 1px; height: 1px; padding-top: 391px; margin-left: 450px;"><div data-drawio-colors="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 11px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; background-color: rgb(255, 255, 255); white-space: nowrap;"><font style="font-size: 14px;">Copy Executed</font></div></div></div></foreignObject><text x="450" y="394" fill="rgb(0, 0, 0)" font-family="jbm" font-size="11px" text-anchor="middle">Copy Executed</text></switch></g><rect x="500" y="310" width="120" height="60" rx="9" ry="9" fill="#cdeb8b" stroke="#36393d" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 340px; margin-left: 501px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; font-weight: bold; white-space: normal; overflow-wrap: normal;">tmux</div></div></div></foreignObject><text x="560" y="344" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle" font-weight="bold">tmux</text></switch></g><path d="M 432.5 245 L 432.5 277.5 L 560 277.5 L 560 299.9" fill="none" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 560 306.65 L 555.5 297.65 L 560 299.9 L 564.5 297.65 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><path d="M 321.25 245 L 321.2 277.5 L 170 277.5 L 170 299.9" fill="none" stroke="#b20000" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 170 306.65 L 165.5 297.65 L 170 299.9 L 174.5 297.65 Z" fill="#b20000" stroke="#b20000" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><rect x="210" y="210" width="445" height="35" rx="5.25" ry="5.25" fill="#cdeb8b" stroke="#36393d" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 443px; height: 1px; padding-top: 228px; margin-left: 211px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>ssh</b></div></div></div></foreignObject><text x="433" y="231" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">ssh</text></switch></g><rect x="0" y="0" width="660" height="160" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><rect x="0" y="0" width="140" height="40" fill="#ffcc99" stroke="#36393d" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 138px; height: 1px; padding-top: 20px; margin-left: 1px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; font-weight: bold; white-space: normal; overflow-wrap: normal;">Client</div></div></div></foreignObject><text x="70" y="24" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle" font-weight="bold">Client</text></switch></g><path d="M 560 100 L 560 155 L 560.17 198.22" fill="none" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 560.2 204.97 L 555.67 195.98 L 560.17 198.22 L 564.67 195.95 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 1px; height: 1px; padding-top: 180px; margin-left: 491px;"><div data-drawio-colors="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 11px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; background-color: rgb(255, 255, 255); white-space: nowrap;"><font style="font-size: 16px;">SSH Connection</font></div></div></div></foreignObject><text x="491" y="184" fill="rgb(0, 0, 0)" font-family="jbm" font-size="11px" text-anchor="middle">SSH Connection</text></switch></g><rect x="500" y="40" width="120" height="60" rx="9" ry="9" fill="#cdeb8b" stroke="#36393d" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 70px; margin-left: 501px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; font-weight: bold; white-space: normal; overflow-wrap: normal;">alacritty<br>(terminal)</div></div></div></foreignObject><text x="560" y="74" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle" font-weight="bold">alacritty...</text></switch></g><path d="M 280 100 L 280 155 L 279.29 199.94" fill="none" stroke="#b20000" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 279.18 206.69 L 274.83 197.62 L 279.29 199.94 L 283.83 197.76 Z" fill="#b20000" stroke="#b20000" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 1px; height: 1px; padding-top: 180px; margin-left: 211px;"><div data-drawio-colors="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 11px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; background-color: rgb(255, 255, 255); white-space: nowrap;"><font style="font-size: 16px;">SSH Connection</font></div></div></div></foreignObject><text x="211" y="183" fill="rgb(0, 0, 0)" font-family="jbm" font-size="11px" text-anchor="middle">SSH Connection</text></switch></g><rect x="220" y="40" width="120" height="60" rx="9" ry="9" fill="#cdeb8b" stroke="#36393d" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 70px; margin-left: 221px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; font-weight: bold; white-space: normal; overflow-wrap: normal;">listener script</div></div></div></foreignObject><text x="280" y="74" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle" font-weight="bold">listener script</text></switch></g></g><switch><g requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility"></g><a transform="translate(0,-5)" xlink:href="https://www.diagrams.net/doc/faq/svg-export-text-problems" target="_blank"><text text-anchor="middle" font-size="10px" x="50%" y="100%">Text is not SVG - cannot display</text></a></switch></svg>

In this model, there are 2 SSH connections. One where I’m accessing my work
environment using `tmux` and altering files with `nvim`. The other listens for
data to be placed in the named piped located at `~/clip`.

For setup in the VM, I first create the named pipe `~/clip`:

```bash
mkfifo ~/clip
```

Next, I need to ensure that any copy request coming out of `tmux` or `nvim`
forwards the data to this named pipe. For `tmux`, I add this to
`~/.config/tmux.conf`:

```bash
set -g mouse on
setw -g mode-keys vi

# map vi keys when in copy-mode for selection and copy (yank)
bind -T copy-mode-vi 'v' send -X begin-selection
bind -T copy-mode-vi 'V' send -X select-line
bind -T copy-mode-vi 'r' send -X rectangle-toggle

# send buffer to ~/clip when copying with 'y'
bind -T copy-mode-vi 'y' send -X copy-pipe-and-cancel "tmux show-buffer > ~/clip"
# send buffer to ~/clip when dragging with the mouse
bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-selection-and-cancel\; run "tmux show-buffer > ~/clip"
```

The key pieces in the above are the `copy-mode-vi` settings that run `tmux
show-buffer > ~/clip` on specific events.

For `nvim`, I setup a dedicated command that will forward selected content to
`~/clip`. I intentionally choose not to hook into yank or override any register
behaviors because I want to keep those as is. Here are the relevant parts of my
function written in lua stored in `init.vim`:

```lua
function SaveSelectionToClipboard()
    -- Save the current selection to the ~/clip file
    vim.cmd([[ '<,'>w! >> ~/clip ]])
  end

  -- Create a mapping to call the function in Visual mode
  vim.api.nvim_set_keymap('v', '<leader>c', ':lua SaveSelectionToClipboard()<CR>', { noremap = true })
```

I believe the equivalent in vimscript would look something like:

```
vnoremap <silent> <your_hotkey> :w! ~/clip<CR>
```

The last step is to connect the client machine (laptop) to the VM. This should
likely be done by using an init system like systemd or homebrew/launchctl to run
it as a service that constantly triggers. However, for the sake of a generic
example, here’s how you can connect using a simple bash loop:

```bash
while true
  do ssh -i ~/.ssh/joshrosso.pem 192.168.1.77 'cat ~/clip' | pbcopy
done
```

In the above, you’ll change `192.168.1.77` to your host’s IP address.
Additionally, if not using MacOS, you’ll swap `pbcopy` out for something that
saves piped output to your clipboard, like `xclip`. If you want to prevent
password prompting for the `ssh` command, you should add this host and identity
file to your `~/.ssh/config`.

Now you’re set to trigger copies on your VM and you should see the contents get
forwarding to your client’s clipboard.

## Conclusion

Hope you enjoyed this random but interesting use case for sharing clipboards
between a guest and host machine!
