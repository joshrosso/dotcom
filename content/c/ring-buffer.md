---
title: 'Ring Buffer'
date: 2023-03-30
weight: 9909
math: true
---

# Ring Buffer

A ring buffer, or circular queue, is my favorite data structure. I’ve used it
countless times throughout my career to solve a myriad of things. Today i’m
going to take you through an example problem, the design of a ring buffer, and
an implementation (in Go).

## Problem

You’re tasked with getting data from thousands of low-powered sensors to a
database. You realize that maintaining connections for each sensor to the
database is not a good architectural decision. Additionally, hitting the
database with an insert for every sensor read will strain the backend. Thus, you
want to create a co-located emitter that can receive sensor data and emit it in
batches every 30 seconds to the database.

<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="100%" viewBox="-0.5 -0.5 1132 441" content="<mxfile host=&quot;app.diagrams.net&quot; modified=&quot;2023-03-24T13:36:33.419Z&quot; agent=&quot;5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36&quot; version=&quot;21.0.8&quot; etag=&quot;mld4RW213fQDwXWysFtU&quot; type=&quot;device&quot;><diagram name=&quot;Page-1&quot; id=&quot;N_1NsE6MjYvNgISBwqey&quot;>5VlLc9sgGPw1PjaDQEj2MXHS9pBOM+ND2yOR0KPBRkUotvvriwRYxpLHjiM7zcQXoQUE7LIfD4/QdL76IkiRfeMxZSMI4tUI3Y4g9DAG6lEja41MQqSBVOSxKdQCs/wvNaCpl1Z5TEunoOScybxwwYgvFjSSDkaE4Eu3WMKZ22pBUtoBZhFhXfRHHstMo2M7rBr/SvM0sy17wOTMiS1sgDIjMV9uQehuhKaCc6lT89WUspo8y4uu93lP7qZjgi7kMRWgrvBMWGXGZvol13awgleLmNblwQjdLLNc0llBojp3qeRVWCbnTL15Kmk+R4Wkq71d8jYDVTOE8jmVYq2K2AqB4cZMDmhpXbZUexODZVs0+3Z6ECNvuvl2y4BKGBL6CUEdQmZ0UXJRvo6XJGdsyhkXTV0UEACSpMb5Qm7hSfNTeCkFf6JbOSgEYDo1NYwjvPGZGIdHMo4GINw/QCwXMuMpXxB2z3lh6PxNpVwbFkgluUu2GrZY/6zrXwHgW+BXA/getsDtyjSh39bmTVNvfY1s/gMVuRocFaaY7jaNdyJFySsRGQib0ERESq0Q/tHiCMqIzJ/dz7+Gadzj9YBJM6ccDYI/FbcZn8qG52tVAHnFqhm6zVeptH7O7JfK6tFiwGKqX1vwFqqbtfCA9orHAIToJfa6xmqmgGHspBY4105h107jHjeFA7gpOKebXCe93EdHWCb8vywTXsAyHSO8rAGIr8YIoT2teB/Pbii4nN3Gw9ttz/KzZznD4QEXnrp2TS5jRFP1gefNbDeSBtDdkODdjYbulqm1I9emG0cpOHnvDocfz+H+BR1uzxSXs3i7QdUWDzA8k8c9e3Z+G5N7rskDcDaT24G+X5ejj+dyfEmXd+9BbokkpeSCdiguM1LUyWjNcsW1QIeJftSq3D9uABI9pY1W3yupPkNtaDAnezyEOqD5uXcGMOwEIDjQLQLArqFRiDsCQr9HQQ8OISHqCFUHv5l5bcP0XYvevNnhqDdkn3RisgHbCeJw+CB+tA5+T6zdFYaxvCjpYd+QstD3t0m+qmUaYp7i8c40Bd04swkq29N0mEjz+lsY6O9ZJG6qJFGT6ciV4nQR/qtlY3cbgVCPnF6fnCdcF6vX9m5eb0TafzjQ3T8=</diagram></mxfile>" style="background-color: rgb(255, 255, 255);"><defs></defs><g><rect x="0" y="30" width="190" height="410" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></rect><rect x="0" y="0" width="190" height="30" fill="#6a00ff" stroke="#3700cc" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 188px; height: 1px; padding-top: 15px; margin-left: 1px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 18px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">Sensors</div></div></div></foreignObject><text x="95" y="20" fill="#ffffff" font-family="jbm" font-size="18px" text-anchor="middle">Sensors</text></switch></g><path d="M 135 98.13 L 411.48 188.9" fill="none" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 417.89 191 L 407.94 192.47 L 411.48 188.9 L 410.75 183.92 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><rect x="55" y="50" width="80" height="70" fill="#d80073" stroke="#a50040" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 78px; height: 1px; padding-top: 85px; margin-left: 56px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><font style="font-size: 31px;">S<sub>0</sub></font></div></div></div></foreignObject><text x="95" y="89" fill="#ffffff" font-family="jbm" font-size="12px" text-anchor="middle">S0</text></switch></g><path d="M 135 179.92 L 409.97 213.77" fill="none" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 416.67 214.59 L 407.19 217.96 L 409.97 213.77 L 408.29 209.02 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><rect x="55" y="140" width="80" height="70" fill="#d80073" stroke="#a50040" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 78px; height: 1px; padding-top: 175px; margin-left: 56px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><font style="font-size: 31px;">S</font><font style="font-size: 25.8333px;">1</font></div></div></div></foreignObject><text x="95" y="179" fill="#ffffff" font-family="jbm" font-size="12px" text-anchor="middle">S1</text></switch></g><path d="M 135 269.96 L 411.06 235.16" fill="none" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 417.75 234.32 L 409.39 239.91 L 411.06 235.16 L 408.26 230.98 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><rect x="55" y="240" width="80" height="70" fill="#d80073" stroke="#a50040" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 78px; height: 1px; padding-top: 275px; margin-left: 56px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><font style="font-size: 31px;">S</font><font style="font-size: 25.8333px;">2</font></div></div></div></foreignObject><text x="95" y="279" fill="#ffffff" font-family="jbm" font-size="12px" text-anchor="middle">S2</text></switch></g><path d="M 135 360.54 L 414.55 259.48" fill="none" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 420.9 257.18 L 413.96 264.47 L 414.55 259.48 L 410.9 256.01 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><rect x="55" y="340" width="80" height="70" fill="#d80073" stroke="#a50040" pointer-events="all"></rect><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 78px; height: 1px; padding-top: 375px; margin-left: 56px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><font style="font-size: 31px;">S</font><font style="font-size: 25.8333px;">3</font></div></div></div></foreignObject><text x="95" y="379" fill="#ffffff" font-family="jbm" font-size="12px" text-anchor="middle">S3</text></switch></g><path d="M 890 170 C 890 161.72 943.73 155 1010 155 C 1041.83 155 1072.35 156.58 1094.85 159.39 C 1117.36 162.21 1130 166.02 1130 170 L 1130 260 C 1130 268.28 1076.27 275 1010 275 C 943.73 275 890 268.28 890 260 Z" fill="#d80073" stroke="#000000" stroke-width="2" stroke-miterlimit="10" pointer-events="all"></path><path d="M 1130 170 C 1130 178.28 1076.27 185 1010 185 C 943.73 185 890 178.28 890 170" fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" pointer-events="all"></path><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 238px; height: 1px; padding-top: 228px; margin-left: 891px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 27px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">Datastore</div></div></div></foreignObject><text x="1010" y="236" fill="#ffffff" font-family="jbm" font-size="27px" text-anchor="middle">Datastore</text></switch></g><path d="M 690 215 L 879.9 215" fill="none" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="stroke"></path><path d="M 886.65 215 L 877.65 219.5 L 879.9 215 L 877.65 210.5 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-width="3" stroke-miterlimit="10" pointer-events="all"></path><ellipse cx="555" cy="215" rx="135" ry="135" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"></ellipse><ellipse cx="555" cy="215" rx="105" ry="105" fill="#d80073" stroke="#a50040" pointer-events="all"></ellipse><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 208px; height: 1px; padding-top: 215px; margin-left: 451px;"><div data-drawio-colors="color: #ffffff; " style="display: flex; box-sizing: border=box font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: jbm; color: rgb(255, 255, 255); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><font style="font-size: 24px;">Buffer</font></div></div></div></foreignObject><text x="555" y="219" fill="#ffffff" font-family="jbm" font-size="12px" text-anchor="middle">Buffer</text></switch></g></g><switch><g requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility"></g><a transform="translate(0,-5)" xlink:href="https://www.diagrams.net/doc/faq/svg-export-text-problems" target="_blank"><text text-anchor="middle" font-size="10px" x="50%" y="100%">Text is not SVG - cannot display</text></a></switch></svg>

Situations like this often require consideration around:

1. What should our max batch size be?
2. What should we do if sensor data enters when the batch size is reached?
    1. Can be caused by a database connection issue, outage, or sensors emitting to much data.

While this condition is unideal, there’s a commonly taken trade-off here. Rather
than trying to deal with
[backpressure](https://en.wikipedia.org/wiki/Backpressure_routing#:~:text=Backpressure%20routing%20is%20an%20algorithm,with%20wireless%20and%20wireline%20components.),
it may be best to just **drop the oldest data stored in the emitter** and
**ensure** **whatever is queued up for the next emit** **is the newest**. This
way, while there’s data loss, we can ensure we have the most up-to-date signal
from the sensors.

To solve the above, we’ll design and implement ring buffer.

## Buffer Design

In its simplest form, this buffer is essentially an array where the index
`length(array) + 1` = `array[0]`. Or:

$$
array = a_1, a_2, \ldots a_{n}
\newline
a_{n+1}=a_{1}
$$

Notation aside, this creates a circle (*************conceptually)*************
out of the array. Wikipedia has an excellent graphic:

![wikipedia: ring-buffer](https://upload.wikimedia.org/wikipedia/commons/f/fd/Circular_Buffer_Animation.gif)



While this representation is true to our future implementation, there are a few
key things to point out:

- Our read (emit) will (eventually) be triggered by time.
- We’ll allow overwriting should the write pointer reach, or pass, the read
  pointer.

With the conceptual idea of this data structure in place, lets build it.

## Implementation

Throughout this section I’ll show snippets of code for brevity. To see the
entire implementation visit
[https://github.com/joshrosso/ringbuffer](https://github.com/joshrosso/ringbuffer).

First, we’ll start off with the data structure:

```go
// RingBuffer is a circular buffer for storing [Data].
// It allows for writing and emitting data. When the
// buffer is full, the oldest data is overwritten.
type RingBuffer struct {
	data []*Data
	// total size of buffer
	size int
	// last element that was writtent to in buffer
	lastInsert int
	// next element to read during emit
	nextRead int
	// time between emit cycles
	emitTime time.Time
}

// Data represents input received from sensors.
type Data struct {
	Stamp time.Time
	Value string
}
```

Next a constructor for `RingBuffer`.

```go
func NewRingBuffer(size int) *RingBuffer {
	return &RingBuffer{
		data: make([]*Data, size),
		size: size,
		// initialize to -1 so that we can discern when
		// no insert has occured.
		lastInsert: -1,
	}
}
```

Note that `data` gets initialized to the exact `size` for the buffer. This
ensures [there is no overhead in Go needing to reallocate arrays as the slice
grows](https://go.dev/blog/slices-intro).

Next let’s create an API for inserting to the ring buffer.

```go
// Insert adds a new [Data] to the [RingBuffer].
// If the buffer is full, the oldest data is overwritten.
func (r *RingBuffer) Insert(input Data) {
	r.lastInsert = (r.lastInsert + 1) % r.size
	r.data[r.lastInsert] = &input

	if r.nextRead == r.lastInsert {
		r.nextRead = (r.nextRead + 1) % r.size
	}
}
```

There’s a bit of cleverness here with expressions like `(r.lastInsert + 1) %
r.size`. This expression enabled us to move forward in the buffer, ensuring that
if we’re at the end of the array, we start at the beginning. To make the example
concrete, consider an array of size `5` where we want to move to the "next"
element from index `4`:

$$
nextIndex = ((4 + 1)\mod 5) = 0
$$

With insert in place, we can now implement the emit functionality.

```go
// Emit returns all data in [RingBuffer] since the last call
// to Emit.  If no data has been written since the last call
// to Emit, an empty slice is returned.
func (r *RingBuffer) Emit() []*Data {
	output := []*Data{}
	for {
		if r.data[r.nextRead] != nil {
			output = append(output, r.data[r.nextRead])
			r.data[r.nextRead] = nil
		}
		if r.nextRead == r.lastInsert || r.lastInsert == -1 {
			break
		}
		r.nextRead = (r.nextRead + 1) % r.size
	}
	return output
}
```

As a final step, you can setup main such that it validates the buffer behavior.

```go
func main() {
	rb := NewRingBuffer(5)
	currentRune := 'a' - 1
	fmt.Println("EMPTY TEST:")
	spew.Dump(rb.Emit())
	fmt.Println("FULL TEST:")
	for i := 0; i < 10; i++ {
		currentRune++
		rb.Insert(Data{
			Stamp: time.Now(),
			Value: string(currentRune),
		})
	}
	spew.Dump(rb.Emit())
}
```

In the 2 tests above, the `EMPTY TEST` will return an empty slice and `FULL
TEST` will return f, g, h, i k.

```go
EMPTY TEST:
([]*main.Data) {
}

FULL TEST:
([]*main.Data) (len=5 cap=8) {
 (*main.Data)(0xc000108540)({
  Stamp: (time.Time) 2023-03-24 07:07:11.779010999 -0600 MDT m=+0.000126421,
  Value: (string) (len=1) "f"
 }),
 (*main.Data)(0xc000108570)({
  Stamp: (time.Time) 2023-03-24 07:07:11.77901113 -0600 MDT m=+0.000126550,
  Value: (string) (len=1) "g"
 }),
 (*main.Data)(0xc0001085a0)({
  Stamp: (time.Time) 2023-03-24 07:07:11.779011261 -0600 MDT m=+0.000126684,
  Value: (string) (len=1) "h"
 }),
 (*main.Data)(0xc0001085d0)({
  Stamp: (time.Time) 2023-03-24 07:07:11.779011404 -0600 MDT m=+0.000126826,
  Value: (string) (len=1) "i"
 }),
 (*main.Data)(0xc000108600)({
  Stamp: (time.Time) 2023-03-24 07:07:11.779011556 -0600 MDT m=+0.000126978,
  Value: (string) (len=1) "j"
 })
}
```

In the case of `FULL TEST`, `a` through `j` are inserted into the ring buffer,
but since the size is set to `5`, `a` through `e` are overwritten and when emit
is called, `f` through `j` is all that remains.

Now that we’ve got functionality validated around the buffer, the final step
you’d setup is to create a Run() function that can be called in a separate Go
routine. You can use the `emitTime` property setup in the `RingBuffer` struct to
configure a loop using `time.Sleep`. Note that if you go this extra step, it
becomes extra important you consider a mutex that can lock the buffer during an
emit cycle!

Wrapping up this exercise, there are a few items of note.

- You should consider needs around thread safety. It’s not handled here in order
  to keep the code samples succinct, but mutex’s when doing emit and potentially
  even insert should be considered.
- If you find expression like `(r.nextRead + 1) % r.size` ugly, one way to clean
  it up would be to introduce a new type for `lastInsert` and `nextRead` that
  holds an int and has a method for `Next()`, this would abstract the idea of
  wrapping around the data structure.
- In `Emit`, we set the `Data` read to nil. This could trigger some garbage
  collection prematurely, however I think this keeps the state of the data
  structure clean and is an optimization that won’t see significant benefit in
  most cases.
- Go has a [ring package](https://pkg.go.dev/container/ring), but I’m not too
  crazy about its API and its implemented as a linked list, which is likely to
  have lesser performance since its non-contiguous memory.

## Closing

One of the beauties of data structures is that we can solve so many problems
adding a little sugar on top of an array or map (hash table). This small
implementation can solve some real-world problems and is a great tool to have in
the belt. I also love some of the tricks like using modulo to ensure we end up
back at index `1` if we’re trying to get the next element at the end of the
array. Simply put, I find it really weirdly inspiring knowing simple solutions
with known primitives are often just sitting amongst us waiting to be used 🙂.
Hope you found this interesting and happy building!
