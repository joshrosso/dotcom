---
title: 'Time-based KV Store in Go (Interview Question)'
date: 2023-03-18
weight: 9910
math: true
---

# Time-based KV Store in Go (Interview Question)

I recently got the [Time Based Key-Value
Store](https://leetcode.com/problems/time-based-key-value-store/) problem in a
technical interview. It’s a fun exercise, and I believe there might a
interesting spin one could put on it. What follows is **not** a recommendation
for an interview question, more-so just an interesting modification to the
problem for us to ponder and solve.

_Content in video form if that's more of your thing:_

{{< youtube qG4X7d8LgzQ >}}

**The original question breaks down to the following:**

- Create a new data-structure named `TimeMap`.
- Implement `set(String key, String value, int timestamp)`
- Implement `String get(String key, int timestamp)`
    - Based on `timestamp`, all values that are less than or equal to this value
      should be returned.

**The following is assumed:**

- You may use the standard library.
- Keys are always `set` chronologically.

The standard solution to the problem is to use a `map` of keys that hold a list
of values. Since the values can be assumed to be retrieved chronologically, you
can use binary search to find the first key larger than the time stamp asked for
in the `get` call. Then you return all elements lower than it. This solution has
a time complexity of:

$$
set = O(1) \newline
get = O(log\ n)
$$

## Enhancements

Some of these enhancements are inspired by the specific questions asked of me,
while others are ideas I came up with (I'm trying not to give too much away
about the specific interview).

In this new question, we’re going to keep most properties the same. Here are the
changes:

- `set` no longer takes a timestamp; it’s calculated at time of call.
    - Time precision should be to the nanosecond.
- `get` accepts the timestamp **optionally.**
- When `get` receives ****************************no
  timestamp**************************** return the latest value for the key.
- When `get` receives a timestamp, return a single element at that timestamp.
- Implement `String getBefore(String key, int timestamp)`, which effectively
  does what the original `get` asked for.

Extra considerations:

- Attempt to keep time complexity of `get` as low as possible.
    - Ideally `O(1)`.
    - Try to be efficient with memory, but lookup time is more important.
- String is used as the value for simplicity, but pretend the value can be a
  sizable object.

With these changes in mind, we need to enhance the data structure to optimize
around `get`. Specifically, we need to set something up that can get us a
constant lookup time regardless of whether the user asks for a specific time or
not (ie gets the latest).

## Solution: Design

First, let’s consider the data structure we want to build. In order to
facilitate `O(1)` on `get`, we can create something like:

<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="100%" viewBox="-0.5 -0.5 781 341" content="<mxfile host=&quot;app.diagrams.net&quot; modified=&quot;2023-03-18T12:55:53.278Z&quot; agent=&quot;5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36&quot; version=&quot;20.8.12&quot; etag=&quot;Ec2dr6jSkkWjOaReI-xI&quot; type=&quot;device&quot;><diagram name=&quot;Page-1&quot; id=&quot;lL2flwJLBxz_J78wSu8R&quot;>3Vpbc6IwGP01vu7kAoiPq3Zvs53ZGXdmt4+pRGCLxA2x6v76DZIIMUhti6L2peTkCyTnOye3todH8/VnThbRPQto0kMgWPfwuIcQhANH/sqRjUI84BVIyONAYSUwif9RBQKFLuOAZkagYCwR8cIEpyxN6VQYGOGcrcywGUvMry5ISC1gMiWJjf6KAxEVqO+CEv9C4zDSX4ZA1cyJDlZAFpGArSoQvuvhEWdMFE/z9YgmOXual6LdpwO1u45xmopjGqCiwTNJlmpsql9iowdLAzl2VWRcRCxkKUnuSnTI2TINaP5GIEtlzHfGFhKEEvxDhdioRJKlYBKKxDxRtcU38w8Zw8jYkk8VhFWaCQ+pGplrDxbuKJTio2xOBd/IEE4TIuJn8+1EiSDcxZU8yQdFVT1t2KLtZzyn92RhsWdys4piQScLsh3VSrrD5GEWJ8mIJYxv2+IZIBgQiWeCsydaqRmO+wDkL5yxVFRwsP3ZMfpMuaDrg9I4wJZqoNWsTYpVeVUqHmoZRxW1e+D9/DoXqkLXVqHfvgq3TT9yTjaVgAWLU5FV3vwjB8p0Ydc18oXwnvP34iEETfHyoehBma/dUI5KoWtZ5InKph97yEskT8NHLp9CseXd+7vMJ7xhwMKyYEngBfOY+W/BALtJWjvAsR2A+jUOcFpwgHctE7NvWwKCo6lufWbuXzNvTne8+RZvQq5oE8E4vd01DflnXNMGXQhR8sI3v1X7beEhL3xwdXG8rlaON8b02Shg7fKqgl+RkdYVrPtTkfD2MXvtQtKeYltfkvb068Az6hdCi8izCrjU7IMh2XoB03UsKs1k6aFSUzbKC68RvVMzbXsdir6T5e0aknKCffnRScHXlJQ3Eow63OTp/uztVr5KAtc3NNvvH0DOul2B7q2J2KsRMepQxPYR79AJ+RtJZSBKgx4a5Q8A2TPMuU/HuL8nzkGNOJ0TnY5h/9bEWXMcPMVm+k1XSx4wU4395qsl7LtN8e++WoL2YbXZOTATF+QcF3fpnI6Poa07B9UdQ/GFOKfv7Tln0Owc13Ob4t/tHGSfkZudg/klrTneoEPn6O4aV4v6snrF2OyCrq6x8/JFweBEG0e9p6rl6ZHwpwviycEd8mT/EbFkJmKr5IJ4ctHZeJLF8s/fxRRX/hcBvvsP</diagram></mxfile>" style="background-color: rgb(255, 255, 255);"><defs></defs><g><path d="M 120 30 L 163.63 30" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 168.88 30 L 161.88 33.5 L 163.63 30 L 161.88 26.5 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><rect x="0" y="0" width="120" height="60" fill="#f0a30a" stroke="#bd7000" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 30px; margin-left: 1px;"><div data-drawio-colors="color: #000000; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">TimeMap</div></div></div></foreignObject><text x="60" y="34" fill="#000000" font-family="jbm" font-size="12px" text-anchor="middle">TimeMap</text></switch></g><path d="M 305 50 L 305 100 L 60 100 L 60 143.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 60 148.88 L 56.5 141.88 L 60 143.63 L 63.5 141.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><rect x="170" y="10" width="270" height="40" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 268px; height: 1px; padding-top: 30px; margin-left: 171px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">key:<br>"dog"</div></div></div></foreignObject><text x="305" y="34" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">key:...</text></switch></g><path d="M 60 210 L 60 273.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 60 278.88 L 56.5 271.88 L 60 273.63 L 63.5 271.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><path d="M 120 180 L 163.63 180" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 168.88 180 L 161.88 183.5 L 163.63 180 L 161.88 176.5 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><rect x="0" y="150" width="120" height="60" fill="#f0a30a" stroke="#bd7000" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 180px; margin-left: 1px;"><div data-drawio-colors="color: #000000; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">timeStore</div></div></div></foreignObject><text x="60" y="184" fill="#000000" font-family="jbm" font-size="12px" text-anchor="middle">timeStore</text></switch></g><path d="M 120 310 L 283.63 310" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 288.88 310 L 281.88 313.5 L 283.63 310 L 281.88 306.5 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><rect x="0" y="280" width="120" height="60" fill="#f0a30a" stroke="#bd7000" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 310px; margin-left: 1px;"><div data-drawio-colors="color: #000000; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">values</div></div></div></foreignObject><text x="60" y="314" fill="#000000" font-family="jbm" font-size="12px" text-anchor="middle">values</text></switch></g><path d="M 230 150 L 230 130 L 390 130 L 390 153.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 390 158.88 L 386.5 151.88 L 390 153.63 L 393.5 151.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><path d="M 230 150 L 230 130 L 550 130 L 550 153.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 550 158.88 L 546.5 151.88 L 550 153.63 L 553.5 151.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><path d="M 290 180 L 465 180 L 465 130 L 710 130 L 710 153.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 710 158.88 L 706.5 151.88 L 710 153.63 L 713.5 151.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><rect x="170" y="150" width="120" height="60" fill="#f0a30a" stroke="#bd7000" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 180px; margin-left: 171px;"><div data-drawio-colors="color: #000000; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">timeIndex</div></div></div></foreignObject><text x="230" y="184" fill="#000000" font-family="jbm" font-size="12px" text-anchor="middle">timeIndex</text></switch></g><path d="M 390 200 L 390 240 L 425 240 L 425 273.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 425 278.88 L 421.5 271.88 L 425 273.63 L 428.5 271.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><rect x="320" y="160" width="140" height="40" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 138px; height: 1px; padding-top: 180px; margin-left: 321px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">key:<br>Jan 2nd, 2023</div></div></div></foreignObject><text x="390" y="184" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">key:...</text></switch></g><path d="M 550 200 L 550 250 L 335 250 L 335 273.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 335 278.88 L 331.5 271.88 L 335 273.63 L 338.5 271.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><rect x="480" y="160" width="140" height="40" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 138px; height: 1px; padding-top: 180px; margin-left: 481px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">key:<br>Jan 1st, 2023</div></div></div></foreignObject><text x="550" y="184" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">key:...</text></switch></g><path d="M 710 200 L 710 260 L 515 260 L 515 273.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 515 278.88 L 511.5 271.88 L 515 273.63 L 518.5 271.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"></path><rect x="640" y="160" width="140" height="40" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 138px; height: 1px; padding-top: 180px; margin-left: 641px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">key:<br>Jan 3rd, 2023</div></div></div></foreignObject><text x="710" y="184" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">key:...</text></switch></g><rect x="290" y="280" width="90" height="60" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 88px; height: 1px; padding-top: 310px; margin-left: 291px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">"woof"</div></div></div></foreignObject><text x="335" y="314" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">"woof"</text></switch></g><rect x="380" y="280" width="90" height="60" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 88px; height: 1px; padding-top: 310px; margin-left: 381px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">"bark"</div></div></div></foreignObject><text x="425" y="314" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">"bark"</text></switch></g><rect x="470" y="280" width="90" height="60" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 88px; height: 1px; padding-top: 310px; margin-left: 471px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">"howl"</div></div></div></foreignObject><text x="515" y="314" fill="rgb(0, 0, 0)" font-family="jbm" font-size="12px" text-anchor="middle">"howl"</text></switch></g></g><switch><g requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility"></g><a transform="translate(0,-5)" xlink:href="https://www.diagrams.net/doc/faq/svg-export-text-problems" target="_blank"><text text-anchor="middle" font-size="10px" x="50%" y="100%">Text is not SVG - cannot display</text></a></switch></svg>

`TimeMap` is the top-level map that contains the keys. Each key points to a
unique `timeStore`, which holds the `values` list along with a `timeIndex` using
the time stamp of a value as a key and pointing to the value in `values`.

With this data-structure in place, we can return both the latest element and
specific (time-based) element in constant time. When the last element is
desired, we simply return the last element in the `values`. When a specific
timestamp is provided, we can lookup the timestamp since they’re store in the
`timeIndex` map as a key. If a key is present, we can return the value it points
to.

There are a few downsides to consider:

1. While constant time, we are potentially doing 2 extra traversals via
   pointers. This can mean:
    1. Memory of this data structure will grow faster as we maintain the map of
       `timeIndex`.
    2. This pointer-based model means even less contiguous memory, thus our data
       structure has less chance (especially as it grows) [to land in CPU
       cache](https://stackoverflow.com/questions/40071635/cpu-cache-disadvantages-of-using-linked-lists-in-c).
    3. Insertion and deletion is more complex as we need to ensure we manage
       `timeIndex` correctly.

Regarding the `getBefore` implementation, this remains the same as the original
question. Thus our complexity ends up at:

$$
get = O(1) \newline
set = O(1) \newline
getRange = O(log\ n)
$$

## Solution Code

In this section, I’ll be showing and explaining the code chunk by chunk, [to see
the full file, visit the GitHub](https://github.com/joshrosso/time-based-kv).

To begin, let’s create the data structure described above.

```go
// TimeMap holds a key and all values added over time for that key.
type TimeMap struct {
	times map[string]*timeStore
}

// timeStore is the underlying store for each key.
type timeStore struct {
	timeIndex map[time.Time]*value // mapping to each value based on time
	values    []*value             // underlying data store
}

// value represents the object stored.
type value struct {
	stamp time.Time // timestamp of insertion
	val   string    // string used for simplicity, but imagine a larger struct
}
```

Next, we’ll create some helper functions.

```go
// New returns a new [TimeMap].
func New() TimeMap {
	return TimeMap{
		times: map[string]*timeStore{},
	}
}

// newTimeStore is used when a new key is introduced. It intializes and returns
// the pointer to the new key's store.
func newTimeStore() *timeStore {
	return &timeStore{
		timeIndex: map[time.Time]*value{},
		values:    []*value{},
	}
}

func (tm *TimeMap) getTimeStore(key string) (*timeStore, error) {
	if ts, ok := tm.times[key]; ok {
		return ts, nil
	}
	return nil, fmt.Errorf("key [%s] does not exist", key)
}
```

Note that our need for `newTimeStore` is to have an easy way to create a new
store when a new key is created in the `TimeMap`. Additionally, `getTimeStore`
is a helper function to quickly lookup a key’s existence and return an error if
not. This will be reused in our our `get*` implementations.

The first function to implement is `Set`:

```go
// Set adds a value to a given key. When the value is added, its time stamp is
// recorded.
func (tm *TimeMap) Set(key, data string) {
	// when the key exists, insert the value into the store
	if timeStore, ok := tm.times[key]; ok {
		stamp := time.Now()
		v := &value{stamp: stamp, val: data}
		timeStore.values = append(timeStore.values, v)
		timeStore.timeIndex[stamp] = v
		return
	}
	// when the key is new, create a new store for the key and recall this
	// method
	tm.times[key] = newTimeStore()
	tm.Set(key, data)
}
```

`Set` focuses on 2 outcomes, whether the key exists or not. When the key exists,
it’s simply a matter of recording the timestamp and inserting the value into the
existing `timeStore`. When the key does not exist, we need to create a new
`timeStore` associated with that key. Once that `timeStore` exists, recursively
calling this function guarantees the value-insertion (condition 1) logic is run.
There is a case to be made that the recursive call is unnecessarily ‘clever’,
however I feel it’s fine.

With set in place, we can do some simple testing in a `main()` function:

```go
tm := New()
kvs := map[string][]string{
	"dog": {"woof", "bark", "sigh", "growl", "wimper"},
	"cat": {"hiss", "screech", "crash", "meow"},
}
for k, sounds := range kvs {
	for _, sound := range sounds {
		tm.Set(k, sound)
	}
}
spew.Dump(tm)
```

`spew` can be retrieved for your project via `go get
[github.com/davecgh/go-spew/spew](http://github.com/davecgh/go-spew/spew)`,
it’ll enable us to view the end state of the data structure:

```go
(main.TimeMap) {
 times: (map[string]*main.timeStore) (len=2) {
  (string) (len=3) "cat": (*main.timeStore)(0x1400007c0c0)({
   timeIndex: (map[time.Time]*main.value) (len=4) {
    (time.Time) 2023-03-17 18:58:21.721497 -0600 MDT m=+0.000864293: (*main.value)(0x140000643f0)({
     stamp: (time.Time) 2023-03-17 18:58:21.721497 -0600 MDT m=+0.000864293,
     val: (string) (len=4) "hiss"
    }),
    (time.Time) 2023-03-17 18:58:21.742538 -0600 MDT m=+0.021904918: (*main.value)(0x14000180000)({
     stamp: (time.Time) 2023-03-17 18:58:21.742538 -0600 MDT m=+0.021904918,
     val: (string) (len=7) "screech"
    }),
    (time.Time) 2023-03-17 18:58:21.763635 -0600 MDT m=+0.043003168: (*main.value)(0x14000064420)({
     stamp: (time.Time) 2023-03-17 18:58:21.763635 -0600 MDT m=+0.043003168,
     val: (string) (len=5) "crash"
    }),
    (time.Time) 2023-03-17 18:58:21.783989 -0600 MDT m=+0.063356585: (*main.value)(0x14000180030)({
     stamp: (time.Time) 2023-03-17 18:58:21.783989 -0600 MDT m=+0.063356585,
     val: (string) (len=4) "meow"
    })
   },
   values: ([]*main.value) (len=4 cap=4) {
    (*main.value)(0x140000643f0)({
     stamp: (time.Time) 2023-03-17 18:58:21.721497 -0600 MDT m=+0.000864293,
     val: (string) (len=4) "hiss"
    }),
    (*main.value)(0x14000180000)({
     stamp: (time.Time) 2023-03-17 18:58:21.742538 -0600 MDT m=+0.021904918,
     val: (string) (len=7) "screech"
    }),
    (*main.value)(0x14000064420)({
     stamp: (time.Time) 2023-03-17 18:58:21.763635 -0600 MDT m=+0.043003168,
     val: (string) (len=5) "crash"
    }),
    (*main.value)(0x14000180030)({
     stamp: (time.Time) 2023-03-17 18:58:21.783989 -0600 MDT m=+0.063356585,
     val: (string) (len=4) "meow"
    })
   }
  }),
  (string) (len=3) "dog": (*main.timeStore)(0x1400007c100)({
   timeIndex: (map[time.Time]*main.value) (len=5) {
    (time.Time) 2023-03-17 18:58:21.887096 -0600 MDT m=+0.166465210: (*main.value)(0x140000644e0)({
     stamp: (time.Time) 2023-03-17 18:58:21.887096 -0600 MDT m=+0.166465210,
     val: (string) (len=6) "wimper"
    }),
    (time.Time) 2023-03-17 18:58:21.80502 -0600 MDT m=+0.084387918: (*main.value)(0x14000064480)({
     stamp: (time.Time) 2023-03-17 18:58:21.80502 -0600 MDT m=+0.084387918,
     val: (string) (len=4) "woof"
    }),
    (time.Time) 2023-03-17 18:58:21.826097 -0600 MDT m=+0.105464793: (*main.value)(0x14000180060)({
     stamp: (time.Time) 2023-03-17 18:58:21.826097 -0600 MDT m=+0.105464793,
     val: (string) (len=4) "bark"
    }),
    (time.Time) 2023-03-17 18:58:21.846546 -0600 MDT m=+0.125914460: (*main.value)(0x140000644b0)({
     stamp: (time.Time) 2023-03-17 18:58:21.846546 -0600 MDT m=+0.125914460,
     val: (string) (len=4) "sigh"
    }),
    (time.Time) 2023-03-17 18:58:21.867033 -0600 MDT m=+0.146401293: (*main.value)(0x14000180090)({
     stamp: (time.Time) 2023-03-17 18:58:21.867033 -0600 MDT m=+0.146401293,
     val: (string) (len=5) "growl"
    })
   },
   values: ([]*main.value) (len=5 cap=8) {
    (*main.value)(0x14000064480)({
     stamp: (time.Time) 2023-03-17 18:58:21.80502 -0600 MDT m=+0.084387918,
     val: (string) (len=4) "woof"
    }),
    (*main.value)(0x14000180060)({
     stamp: (time.Time) 2023-03-17 18:58:21.826097 -0600 MDT m=+0.105464793,
     val: (string) (len=4) "bark"
    }),
    (*main.value)(0x140000644b0)({
     stamp: (time.Time) 2023-03-17 18:58:21.846546 -0600 MDT m=+0.125914460,
     val: (string) (len=4) "sigh"
    }),
    (*main.value)(0x14000180090)({
     stamp: (time.Time) 2023-03-17 18:58:21.867033 -0600 MDT m=+0.146401293,
     val: (string) (len=5) "growl"
    }),
    (*main.value)(0x140000644e0)({
     stamp: (time.Time) 2023-03-17 18:58:21.887096 -0600 MDT m=+0.166465210,
     val: (string) (len=6) "wimper"
    })
   }
  })
 }
} 
```

While that’s a lot of output, it does give us a solid visual of the data
structure. Some key notes are:

- `TimeMap` has 2 keys: `dog` and `cat`.
- Each key has its own `timeStore`.
- Every `timeStore` holds the values in `values` and a `timeIndex`, which uses
  the insertion time as the key and hold a **pointer** to the value.
    - for example, in the key `dog`, you can see the `values` slice and
      `timeIndex` map hold the **same value**,  `0x14000064480`, which is the
      memory address of `woof`.

If your lost, consider reviewing this output against the diagram in the
`Solution Design` above.

*Going forward, I won’t print the `spew.Dump` output, but  if you’re following
along you should continue testing with it.*

Next we can implement the `Get` function:

```go
// Get returns a value for key. If stamp is provided, the value with that
// timestamp is returned. If stamp is not provided, the last element inserted
// under key is returned.
func (tm *TimeMap) Get(key string, stamp ...time.Time) (*value, error) {
	ts, err := tm.getTimeStore(key)
	if err != nil {
		return nil, err
	}

	// return latest
	if len(stamp) < 1 {
		return ts.values[len(ts.values)-1], nil
	}
	lookup := stamp[0]
	if v, ok := ts.timeIndex[lookup]; ok {
		return v, nil
	}
	return nil, fmt.Errorf("key [%s] had no timestamp [%s]", key, lookup)
}
```

`Get` uses the variadic argument `stamp` to make it optional. [This has some
trade-offs but is a common approach in
Go](https://stackoverflow.com/questions/2032149/optional-parameters-in-go). When
no stamp is provided, we return the last element within `values` as this will be
the last element added. When the stamp is provided, we look it up in the
`timeIndex`. By using `time.Time`, i’m requiring precision down to the
nanosecond, which might not be desired, so you can work with the time precision
on your insert / lookups. For the sake of testing, you can easily capture some
known time stamps and test `Get`, heres how I’ve done it in `main`:

```go
// validate Get for latest
spew.Dump(tm.Get("dog"))

// validate get for each stamp
for stamp := range tm.times["dog"].timeIndex {
	noise, err := tm.Get("dog", stamp)
	if err != nil {
		panic(err)
	}
	fmt.Printf("At %s: %s\n", stamp, noise.val)
}
```

Next let’s implement `GetBefore`:

```go
// GetBefore returns all values stored for key, where their insertion time is
// equal to or before stamp.
func (tm *TimeMap) GetBefore(key string, stamp time.Time) ([]*value, error) {
	ts, err := tm.getTimeStore(key)
	if err != nil {
		return nil, err
	}

	// locate the lowest element with a timestamp lower than stamp
	idx := sort.Search(len(ts.values), func(i int) bool {
		return ts.values[i].stamp.After(stamp)
	})
	// return the list in for of [0:n). When n is 0, meaning the first element
	// is after stamp, an empty list is returned.
	return ts.values[:idx], nil
}
```

This uses [binary
search](https://cs.opensource.google/go/go/+/refs/tags/go1.20.2:src/sort/search.go;l=58)
via the [sort.Search](https://pkg.go.dev/sort#Search) function in the standard library.
The nice thing about `sort.Search` is that it finds the
**************************lowest************************** element that matches
the condition. The index returned, `idx`, can be used to return a subset of the
slice with the `[:idx]` notation. Note that in this notation `idx` is not
inclusive, thus it works perfect for us in all cases. This can also be tested in
`main` using the following logic:

```go
// collect a list of all stamps for dog
collectedStamps := []time.Time{}
for _, v := range tm.times["dog"].values {
	collectedStamps = append(collectedStamps, v.stamp)
}
stampIdxToTest := 2
fmt.Printf("searching before %s\n", collectedStamps[stampIdxToTest])

// Uncomment this and pass testTime below to test a time before all elements
//testTime, err := time.Parse("2006-01-02", "2006-01-02")
// if err != nil {
// 	panic(err)
// }

before, err := tm.GetBefore("dog", collectedStamps[stampIdxToTest])
if err != nil {
	panic(err)
}
spew.Dump(before)
```

And that’s it! Now we have a fully functioning `TimeMap` is `Set`, `Get`, and
`GetBefore` implemented.

Wrapping up, here are a few things to consider about this solution:

- All variants of get return a pointer to a value, this would allow the caller
  to mutate the value, so returning a copy might be desirable.
- `TimeMap` is not thread safe, thread safety would require locks/mutexs.
- There are many things this code is simplifying for brevity, e.g. `panic(err)`.
  After all, this is a coding interview, so it’s not meant to be practical 😆.

## Closing

While the original interview question is interesting, it may be too complex for
a standard coding interview. However, the exercise does offer valuable insight
into the process of designing efficient data structures and algorithms, in
contrast to a more straightforward binary search implementation. As a final
note, I should disclose that I’m not a fan of live coding interviews like this.
Trust me when I say that the pressure causes me to seem like I’m programming for
the first time in my life 🙂. While I do think orgs that can afford it should
consider a more thoughtful/practical interview process, these kinds of exercises
are really fun!
