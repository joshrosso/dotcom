---
title: 'Pipes: Named and Unnamed'
date: 2023-03-23
weight: 9909
---

# Pipes: Named and Unnamed

Pipes are cool. We all use them, but have you ever considered what's happening
behind the scenes? Additionally, did you know there's a way to persist them to
act as simple queues, facilitating interprocess communication? I'll be delving
into pipes today. Let's go!

{{< youtube _TiDWJ-W8nA >}}

## Pipe

A Unix pipe is a form of redirection that allows data to flow from one command
to another, connecting the output of one command to the input of another command
without using an intermediate file. Pipes are a powerful feature of Unix-like
operating systems and can be used to create complex command pipelines for
achieving higher-level tasks.

I'm certain many of you have used pipes extensively. Consider a common example
where you want to navigate JSON in a human-readable format:

```bash
curl https://dummyjson.com/products | jq . | less
```

For some pipe appreciation, consider what this might look like without a `|`.

```bash
curl https://dummyjson.com/products -o products.json &&\
  jq . products.json > products.json &&\
  less products.json &&\
  rm products.json
```

When chaining many commands, pipes become essential to our mental health. Under
the hood, the `|` is doing a `pipe()`
[syscall](https://tldp.org/LDP/lpg/node11.html) that reads the data and allows
the kernel to do some trickery by introducing a set of file descriptors [and
facilitate this through a
buffer](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/linux/pipe_fs_i.h?id=HEAD).
Visually this looks like:

<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="100%" viewBox="-0.5 -0.5 811 232" content="<mxfile host=&quot;app.diagrams.net&quot; modified=&quot;2023-03-20T13:56:02.353Z&quot; agent=&quot;5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36&quot; version=&quot;21.0.8&quot; etag=&quot;0hCijGIVt5TaJqGlsEgv&quot; type=&quot;device&quot;><diagram name=&quot;Page-1&quot; id=&quot;d4rjnelIotYoarM7phFX&quot;>7VlNc9sgEP01nmkPyaAvfxxjJ2k7k047k0PbI5aQRIKFglAs99cXSSAZYSeqrdQZT31IxAKL2ffessIjZ7EqPjGYxl9pgMjIBkExcq5Htj2d2uJvadjUBsuagtoSMRxIW2u4x7+RNKphOQ5Qpg3klBKOU93o0yRBPtdskDG61oeFlOirpjBChuHeh8S0/sABj+W+PNDaPyMcxWplC8ieFVSDpSGLYUDXWybnZuQsGKW8floVC0TK4Km41PNu9/Q2X4yhhPeZIJHI+EbtDQViq7JJGY9pRBNIblrrnNE8CVDpAIhWO+aO0lQYLWF8QJxvJG4w51SYYr4isld8N7b5Wc6/9FTzl3RXNa4LrbWRrYxDxq9K/ITBJzDLsK/Mt5go9xln9LEBRoR0Xm+y3JkWpozmzJcmR9IIsggp2BwzmlaDkSA3oiskvp8YwhCBHD/r7qFkWdSMa4EQDxKL3bjIpZ8hyaVTAygdhnWMObpPYbWftZCdHvJQhGdBCWXVXAdUnyZWqiehSQlwSBO+NTisPk0YnxHjqNjLtz0RkhOcmSS+lL7jyva61ZHSRrwtIaWgY4LqGkG95zAJIAtG9piIleZLpsV4/JSXQqwCcpFVdL4SAyw3LapwqH7xFJX/v+X8FHrSCe+YcEMbANsz4BY941tJhHKLcgHL7ScZz5RMf8VI/C8U2L0VJF19p1is0A6hYZghbrChWbEXQTyDIH7OyKDKG0MAKjHtE5kBkTMBYLHQIarAHECO1rgjx4kpR2uXHt0B5Dh+azl+Sc5FjT1Pvh6inR0jWsmaC3AJZmCmMedd6Xhy2qpGq2naEmdPVbONtXcQW0zGHUYEC/RmwuAFz3SoZOD85dl8B5fi7URDEhIcJaXQRBSQCPa8zLFYlP9XsmOFg6AmDRIrw2Xlr0QiLdlcRcGbj7zrDrotMjuStnxXkc6awl0DY/KiLMGlM7U8XZXHiVLpXflRXm3dwyCanRkEeHg645PXs0948iqhn93rxcQ54euFZRlRJSjLzpjEzY3HSUhs/68fB64fUYF5U8GI560CRrTa+qVsqPKlKXuaGqhf2dOjRFGCOrBGecNqVSXxTrpxu2mk3o2ctX0N13Hk2q84qkPwgqNBz2LLvH5a5mEoaqEtYdUa+eAzBLnguw2WG7P7EbEEkY+mjgjBaYZez38wS+sb3BAXpaoGuYTqvPW6MzNtTXdkrekQWcs9RU55LzeumpK93rgdKdOJ28G7e/zskekhyjGvkM5JORPwz5Qjmu3PIDUS7Y9Jzs0f</diagram></mxfile>" style="background-color: rgb(255, 255, 255);"><defs></defs><g><path d="M 240 108.24 L 240 141.76" fill="none" stroke="rgb(0, 0, 0)" stroke-width="2" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 240 102.24 L 244 110.24 L 240 108.24 L 236 110.24 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="2" stroke-miterlimit="10" pointer-events="all"></path><path d="M 240 147.76 L 236 139.76 L 240 141.76 L 244 139.76 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="2" stroke-miterlimit="10" pointer-events="all"></path><rect x="230" y="0" width="20" height="100" fill="#000000" stroke="none" pointer-events="all"></rect><path d="M 120 50 L 219.9 50" fill="none" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 226.65 50 L 217.65 54.5 L 219.9 50 L 217.65 45.5 Z" fill="#6f0000" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 1px; height: 1px; padding-top: 70px; margin-left: 174px;"><div data-drawio-colors="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 14px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; background-color: rgb(255, 255, 255); white-space: nowrap;">Standard<br style="font-size: 14px;">Out</div></div></div></foreignObject><text x="174" y="74" fill="rgb(0, 0, 0)" font-family="jbm" font-size="14px" text-anchor="middle">Standard...</text></switch></g><rect x="0" y="30" width="120" height="40" fill="#6a00ff" stroke="#3700cc" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 50px; margin-left: 1px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 25px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">curl</div></div></div></foreignObject><text x="60" y="58" fill="#ffffff" font-family="jbm" font-size="25px" text-anchor="middle">curl</text></switch></g><path d="M 349.9 50 L 260.1 50" fill="none" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 356.65 50 L 347.65 54.5 L 349.9 50 L 347.65 45.5 Z" fill="#6f0000" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><path d="M 253.35 50 L 262.35 45.5 L 260.1 50 L 262.35 54.5 Z" fill="#6f0000" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 1px; height: 1px; padding-top: 70px; margin-left: 310px;"><div data-drawio-colors="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 14px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; background-color: rgb(255, 255, 255); white-space: nowrap;">Standard<br style="font-size: 14px;">In</div></div></div></foreignObject><text x="310" y="74" fill="rgb(0, 0, 0)" font-family="jbm" font-size="14px" text-anchor="middle">Standard...</text></switch></g><path d="M 480 50 L 559.9 50" fill="none" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 566.65 50 L 557.65 54.5 L 559.9 50 L 557.65 45.5 Z" fill="#6f0000" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 1px; height: 1px; padding-top: 71px; margin-left: 521px;"><div data-drawio-colors="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 13px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; background-color: rgb(255, 255, 255); white-space: nowrap;">Standard<br style="font-size: 13px;">Out</div></div></div></foreignObject><text x="521" y="74" fill="rgb(0, 0, 0)" font-family="jbm" font-size="13px" text-anchor="middle">Standard...</text></switch></g><rect x="360" y="30" width="120" height="40" fill="#6a00ff" stroke="#3700cc" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 50px; margin-left: 361px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 25px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">jq</div></div></div></foreignObject><text x="420" y="58" fill="#ffffff" font-family="jbm" font-size="25px" text-anchor="middle">jq</text></switch></g><rect x="570" y="0" width="20" height="100" fill="#000000" stroke="none" pointer-events="all"></rect><rect x="690" y="30" width="120" height="40" fill="#6a00ff" stroke="#3700cc" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 50px; margin-left: 691px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 25px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">less</div></div></div></foreignObject><text x="750" y="58" fill="#ffffff" font-family="jbm" font-size="25px" text-anchor="middle">less</text></switch></g><path d="M 679.9 50 L 600.1 50" fill="none" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 686.65 50 L 677.65 54.5 L 679.9 50 L 677.65 45.5 Z" fill="#6f0000" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><path d="M 593.35 50 L 602.35 45.5 L 600.1 50 L 602.35 54.5 Z" fill="#6f0000" stroke="#6f0000" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 1px; height: 1px; padding-top: 70px; margin-left: 644px;"><div data-drawio-colors="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 14px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; background-color: rgb(255, 255, 255); white-space: nowrap;">Standard<br style="font-size: 14px;">In</div></div></div></foreignObject><text x="644" y="74" fill="rgb(0, 0, 0)" font-family="jbm" font-size="14px" text-anchor="middle">Standard...</text></switch></g><ellipse cx="240" cy="190" rx="40" ry="40" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></ellipse><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 78px; height: 1px; padding-top: 190px; margin-left: 201px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">buffer<br>(created by<br>kernel)</div></div></div></foreignObject><text x="240" y="194" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">buffer...</text></switch></g><path d="M 580 108.24 L 580 141.76" fill="none" stroke="rgb(0, 0, 0)" stroke-width="2" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 580 102.24 L 584 110.24 L 580 108.24 L 576 110.24 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="2" stroke-miterlimit="10" pointer-events="all"></path><path d="M 580 147.76 L 576 139.76 L 580 141.76 L 584 139.76 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="2" stroke-miterlimit="10" pointer-events="all"></path><ellipse cx="580" cy="190" rx="40" ry="40" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></ellipse><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 78px; height: 1px; padding-top: 190px; margin-left: 541px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">buffer<br>(created by<br>kernel)</div></div></div></foreignObject><text x="580" y="194" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">buffer...</text></switch></g></g><switch><g requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility"></g><a transform="translate(0,-5)" xlink:href="https://www.diagrams.net/doc/faq/svg-export-text-problems" target="_blank"><text text-anchor="middle" font-size="10px" x="50%" y="100%">Text is not SVG - cannot display</text></a></switch></svg>


Assuming the next process can read standard in, it will take it and operate on
it. Sometimes scripts or tools don't inherently read from standard in, in which
case there are other tricks we could use, such as `xargs`. When you're writing
scripts or command-line tools, I highly recommend supporting standard in since
it makes your tool interoperable with the broader ecosystem.

Let's demonstrate this with a simple tool, `jsonchk`, built in Go, that
determines whether JSON is valid or not. As an argument, it expects a file but
also supports being piped into. The following code achieves this, with comments
explaining some of the standard library uses:

```go
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"time"
)

const (
	invalidJSONMsg = "invalid JSON"
	validJSONMsg   = "valid JSON"
)

// WARNING: code simplified and errors not properly
// considered for brevity.
func main() {
	var jsonData []byte

	// read pipe via stadard in when present
	stat, _ := os.Stdin.Stat()
	// check fileMode is 0, or DIRECTORY
	// check input is Unix Character Device
	// When both ^ are true; we have a pipe
	if (stat.Mode() & os.ModeCharDevice) == 0 {
		jsonData, _ = io.ReadAll(os.Stdin)
	} else {
		// when no standard input existed:
		// expect argument 1 to be a file (or named pipe)
		f, err := os.Open(os.Args[1])
		if err != nil {
			panic(err)
		}
		defer f.Close()
		bRead := bufio.NewReader(f)
		for {
			line, _, err := bRead.ReadLine()
			jsonData = append(jsonData, line...)
			if err != nil {
				break
			}
		}
	}

	// check wether JSON is valid
	if json.Valid(jsonData) {
		fmt.Printf("[%s] received at %s\n", validJSONMsg, time.Now())
		os.Exit(0)
	}
	fmt.Printf("[%s] received at %s\n", invalidJSONMsg, time.Now())
	os.Exit(1)
}
```

To build the above:

```go
go build -o jsonchk .
```

Now we can test a few pipe use cases:

```bash
curl -s https://dummyjson.com/products | ./jsonchk

[valid JSON] received at 2023-03-20 09:44:33.580404 -0600 MDT m=+0.256167251
```

```bash
echo "{{ seems Wr0nG}" | ./jsonchk

[invalid JSON] received at 2023-03-20 09:44:57.091382 -0600 MDT m=+0.000460459
```

This demonstrates the interoperability of our new command with `curl` and
`echo`.

However, our usage of pipe is clearly ephemeral. What if we want to keep a pipe
open over time, perhaps like a channel?

## Named Pipes

Named pipes are an extension of this pipe model, where a file is created to
facilitate processes reading and writing to them. They act as first in first out
(FIFO) queues and can be created using `mkfifo`. This command is available on
most *nix environments. Another cool aspect is that we can largely treat these
as files we’re reading from, they just happen to be cleared when read.

Let’s create a named pipe where processes can write JSON to and `jsonchk` can
report what it found over time.

```bash
mkfifo /tmp/jsonBuffer
```

With the pipe file existing, let’s attach `jsonchk` to it in a continuous loop.

```bash
while true
  do ./jsonchk /tmp/jsonBuffer
done
```

Now from `curl` and `echo`, lets test the same idea, but redirect output to the
named pipe:

```bash
curl -s https://dummyjson.com/products > /tmp/jsonBuffer
echo "{{ seems Wr0nG}" > /tmp/jsonBuffer
```

After running these 2 commands, we can return to the `jsonchk` loop and view the output:

```bash
[valid JSON] received at 2023-03-20 09:49:57.739516 -0600 MDT m=+137.128599542
[invalid JSON] received at 2023-03-20 09:49:57.766027 -0600 MDT m=+0.008085168
```

Along with these example, you could also pass a file, such as `testData.json` to
`./jsonchk`. Meaning it’ll treat files and named pipes similarly!

## Conclusion

Pipes are rad, we all know this. Hopefully you learned something new in this
post or, at least, grew your appreciation for this Unix primitive we often take
for granted 🙂. Lastly, next time you’re writing a command line tool or script,
consider accepting piped input!
