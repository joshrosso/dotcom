---
title: 'Go Generics, a Review'
weight: 9910
description: Go introduced generics in 1.18. Here are my thoughts on them.
date: 2022-05-10
images:
- https://octetz.s3.us-east-2.amazonaws.com/go-generics/go-generics-a-review-title-card.png
---

# Go Generics, a Review

The concept of Generics is a programming paradigm common to many languages[^1].
The popular use of generics is to implement algorithms generically, such that
new data structures can be added without the need to re-implement the algorithm.
Consider a sorting algorithm like quicksort[^2]. Rather than implementing quick
sort `N` times, where `N` is the number of data types you have. You could
instead accept any data type that supports comparison. Now, when you introduce a
new data type, you'd only need to specify how comparison works (e.g. `>` and
`<`) for its potential values. By doing this, the quicksort algorithm would
accept the new data type.

This sorting example is possible using an interface. However, it’s rather ugly
due to some required type inference.

## Disclaimer

I'm just a human on the internet and am especially inexperienced in language
design. Consider the contents a perspective, which is sourced from my unique
angle and programming domain. It may not be applicably to you :).

## Pre-Generics

New comers to Go may wonder, how did you all get along without generics for so
long!? From my perspective, many of our simplistic apps being pushing into some
potential replicated code over clever ways to express things generically was
beneficial for code readability. We also could heavily rely on the Interface
model and data structures we create to accomplish related behaviors to what was
described (quicksort) above. Consider how we can introduce a new type in Go that
can be sorted via the [sort.Sort function](TODO:add link to godoc).

For the sake of example, lets assumes we want to introduce a datastructure that
will contain fruits. The applications knows that all sort operations should
happen based on the size of the fruit. Thus a valid sort order would be:

TOOD(joshrosso): Fruit image

Under the hood, `sort.Sort` relies on quicksort for most sorting needs. The
`sort` package defines an interface named `Interface` (yeah, bummer), which
enables us to specify key operations on a slice.

```go
package main

import (
	"fmt"
	"sort"
)

type FruitList struct {
	Fruits []Fruit
}

type Fruit struct {
	Name string
}

func main() {
	fmt.Println("started app")

	fs := FruitList{
		Fruits: []Fruit{
			{"apple"}, {"melon"}, {"raisin"}, {"melon"},
			{"apple"}, {"raisin"}, {"apple"}, {"raisin"},
		},
	}

	fmt.Printf("List started as: %s\n", fs.Fruits)
	sort.Sort(fs)
	fmt.Printf("List ended as: %s\n", fs.Fruits)
}

func (f FruitList) Less(i, j int) bool {
	var iVal, jVal int

	iVal = ResolveFruitWeight(f.Fruits[i])
	jVal = ResolveFruitWeight(f.Fruits[j])

	return iVal < jVal
}

func (f FruitList) Swap(i, j int) {
	valOfJ := f.Fruits[j]
	f.Fruits[j] = f.Fruits[i]
	f.Fruits[i] = valOfJ
}

func (f FruitList) Len() int {
	return len(f.Fruits)
}

func ResolveFruitWeight(f Fruit) int {
	switch f.Name {
	case "grape":
		return 1
	case "apple":
		return 2
	case "melon":
		return 4
	// must be raisin or unknown fruit
	default:
		return 0
	}
}
```
> [click here for code repo](TODO)

Running the above, you'll see:

```txt
$ go run main.go
started app
List started as: [{apple} {melon} {raisin} {melon} {apple} {raisin} {apple} {raisin}]
List ended as: [{raisin} {raisin} {raisin} {apple} {apple} {apple} {melon} {melon}]
```

With this, we have functionality that is similar to what many languages use
generic programming models for. Looking into the `sort` package, we can see the
quicksort achieves this sort goal by accepting the `Interface` interface.

```go
func quickSort(data Interface, a, b, maxDepth int) {
	// quick sort implementation
}
```

While this model works, I'd venture many non-gophers would feel it's a lot of
extra work and boilerplate to introduce "sortability" to a new type. After all,
languages like C++ offer operator overloading[^3], where the definition of `<`
and `>` can be defined.

```c++
```

With operator overloading, making a type sortable can be as simple as defining
the above and the type is instantly able to be used in a variety of algorithms,
such as quicksort.

That said, Go does **not** support operator overloading, even with the
introduction of generics. It's also missing a few other features many Java and
C++ have become accustomed to when using generics. So what can Go's
functionality around generics offer us?

## Go's Generics

The key to understanding the current state of Go's generics model is to grok the
idea of **constraints**. With constraints you can lean into a specification of
functionality and then accept a variety of types based on it. So how to we
constrain arguments to types with specific functionality? Well, the interface of
course.

## A risk of complexity

## Introduction of alias for Interface

## From Email

Go generics

< succinct description >

<code sample>

This offers comparator-like functionality, which we can now plug into a
generic-ish looking sort.

< sort example >

While much of the ugliness is buried in the comparator implementation, even our
sort had issues. For example, we aren’t returning a known type to the caller,
instead we’re returning a slice with interface{} contents. This leaves
responsibility on the caller to do type inference on the return.

This example illuminates the challenges in doing generic-style programming in
Go. At this point, a library author might cut their losses implement a sort for
each data type. Next, let’s take a look at an approach using generics in Go.

## Alias

Bummer an alias was introduced. I really love that Go strives to have 1 way to
do the same thing. In a world where we only have a `for` loop, do we really need
to introduce an alias to `interface{}`? For me, consistency and readability is
worth the extra 8 characters.

```
// any is an alias for interface{} and is equivalent to interface{} in all ways.
type any = interface{}
```

> From [builtin.go](TODO)

Very minor nit in the grand scheme of things of course :) !

## The Review

I feel the next frontier of Go is fending off new capabilities unless truly
justified. Generics are, probably, justified. What set this language off on the
right foot was the early design approach that said if Ken, Pike, and Greeser
couldn’t agree on how to approach something, they wouldn’t include it. This,
paired with the timing of languages like Java and C++, which are so dense with
many ways to achieve the same thing, go struck a chord with many developers.
Myself included.

On one hand, I feel generics are limited from missing language capabilities like
operator overloading. With operator overloading, we could so easily express the
meaning of greater than (‘>‘) and less then (‘<‘). On the other hand, I’m
thankful we aren’t adding significant complexity with features like C++‘s
template specification. Where you can make a generic function so type-specific
actions in the template implementation.

The primary downside for me: I think generics make Go code less readable. As a
new language feature, in a language that has changed very little since 1.0, it’s
entirely possible my unfamiliarity is inflating this perspective. I do find
myself spending a lot more time reasoning about what arguments a function takes
or which type I should be expecting back.

So finally, my review: Generics in Go are good. I’m glad to have them; I hope I rarely use or run into
them.

## References and Attribution

* [Title card photo by]()

[^1]: [Wikipedia: Programming language support for
  genericity](https://en.wikipedia.org/wiki/Generic_programming#Programming_language_support_for_genericity)

[^2]: [Wikipedia: Quicksort](https://en.wikipedia.org/wiki/Quicksort)

[^3]: [TODO: Operator overloading](operator overloading)

