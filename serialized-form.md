# Scalar mappings

Let's start with the simplest possible cases: 

<table>
<tbody>
<tr><th>Ceylon instance type</th>     <th>JSON representation</th></tr>
<tr><td><code>Null</code></td>        <td><code>null</code> literal</td></tr>
<tr><td><code>Boolean</code></td>     <td><code>true</code>/<code>false</code> literal</td></tr>
<tr><td><code>Integer</code></td>     <td><code>Number</code></td></tr>
<tr><td><code>Float</code>*</td>      <td><code>Number</code></td></tr>
<tr><td><code>String</code></td>      <td><code>String></code></td></tr>
<tr><td><code>Character</code>*</td> <td><code>String></code></td></tr>
</tbody>
</table>

* These have some caveats, read on...

## Character value wrappers

Because JSON lacks a character literal syntax we have to encode 
a character using the available syntax. We usually use a JSON string and 
that works fine when we know the JSON string is supposed to be a 
Ceylon `Character`, but there are cases where that would be 
ambiguous on deserialization.

For example consider the class

    class Ambiguous(charOrString) {
        shared Character|String charOrString;
    }
    
and the instances `Ambiguous('x')` and `Ambiguous("x")`. Without care 
those would both serialize to the JSON

    {
      "charOrString": "x"
    }
    
and what is the deserializer to do? In this case we use a wrapper object for 
the instance referencing the `Character`:

    {
      "charOrString": {
        "class": "ceylon.language::Character",
        "value": "x"
      }
    }

## Float value wrappers

Almost all instances of `Float` are represented as JSON numbers, but 
there are 3 which cannot be directly represented as a JSON
 number: `infinity` (the result of computations such as 1.0/0.0), 
 `-infinity` and "undefined" (a.k.a. NaN, the result of computations such 
 as 0.0/0.0).
 
 In order to be able to serialize these values and we need a way to represent 
 these values in JSON. To do that we use an object wrapper, here's infinity:
 
     {
       "value": "∞"
     }
     
Here's NaN:

     {
       "value": "NaN"
     }

That's how it looks when we know that the value must be a `Float`, but there 
are times when we need to encode the type, in which case:

     {
       "class": "ceylon.language::Float",
       "value": "∞"
     }

So with a couple of exceptions, the "simple" types maps in the "obvious" way. 

# Objects

Instances of `serializable` classes map to JSON objects. 
For example the Ceylon class

    class Person(first, last) {
        shared String first;
        shared String last;
    }
    
when serialized via `serialize(Person("John", "Doe"))` would be represented 
as the JSON object

    {
      "first": "John",
      "last": "Doe"
    }

That representation is fine if the consumer of this JSON knows they're 
expecting a `Person` (whether or not the consumer is a Ceylon program). 
But what if the consumer doesn't know what sort of thing they're expecting?
What if they're expecting a `Person|Organization`, or something even 
more general?

For those cases it's necessary for the *producer* to be explicit by calling 
`serialize<Person|Organization>(johnDoe)`, or
`serialize(johnDoe of Object)` or similar. In this situation alabama 
knows to add extra information to the object, so that the type is 
available to the consumer within the serialized form itself, rather than 
being passed out-of-band:

    {
      "class": "example.package::Person",
      "first": "John",
      "last": "Doe"
    }

The `"class"` key is configurable, as is the invertible mapping used to 
transform the type `Person` to a `String`. In the above example 
we used `"example.package::Person"`, 
but if all the classes in the serialized form came from a single package 
we might have configured the serialize to use just `"Person"`, for example. 

Note: the `"class"` key has to be *first* in the JSON object 
so that the type information can be used to infer the types of the attributes 
corresponding to other keys. This prevents the need to have to read the 
whole JSON tree into memory before deserialization can start.

## Identity

Let's take a moment to step away from the concrete syntax we're using to 
represent various things and talk about something slightly more abstract, but
just as important.

JSON is a tree-like format, but Ceylon instances form directed graphs. In 
some use cases it is acceptable to emit the same subtree multiple times for 
each occurrence of a particular instance in the output graph:

                       C <------- A -------> B
                       |                     |
                       |                     |
                       +--------> D <--------+
                       
    // Sometimes it's OK to emit D more than once
    
    A
      B
        D
      C
        D

  
However this is space inefficient and plain doesn't work when 
the directed graph has a cycle:

                      A -------> B
                      ^          |
                      |          |
                      C <--------+
    
    // We don't want to emit the ABC cycle forever
    
    A
      B
        C
          A
            B
              C ...

So support cycles we need extra information to encode an instance's 
identity.

## Objects with identity

For Ceylon instances which get serialized as JSON objects we can add an 
extra "#" key to encode the identity:

    {
      "#": 123,
      "first": "Jane",
      "second": "Doe"
    }

When an attribute references an object using its identity (rather than
including it as a sub-object) it uses a key ending with a `@`. 
So if John's manager is Jane we might end up with this:

    { 
      "#": 124,
      "first": "John",
      "last": "Doe",
      "manager@": 123
    }
    
(If you're wondering why we need to ugly `@` suffix and why we can't just 
say `"manager": 123` it's because *in general* the type of the `manager`
reference might be `Integer|Person`, and then `"manager": 123` is ambiguous:
Is the value of `manager` suppose to be the `Integer` 123 or the object 
with the id 123?)

**Note:** we only emit an instance's identity if 
that instance is referenced more than once.

# Collections

Ceylon has lots of different "collection"-like 
classes, but JSON has only one, and we want the JSON representation to 
look "natural". So `Array`, `ArraySequence`, `Singleton` and `Tuple` all map 
to JSON array. That creates a problem at deserialization, because when 
confronted with

    [1, "a", true]
    
and no type information we need to know what kind of collection to recreate.

 
(Because we know that `Sequential` is covariant, we can cheat a little.
At serialization-time we only need to know the *base type* of the sequence
because at deserialization time we can use the types of the elements
to compute a sequence type, and that computed sequence type is necessarily a 
subtype of what the serialization-time sequence type was. 
This is a variation of the trick that we use for all Tuple types).

**TODO** span and measure map to JSON arrays, but maybe shouldn't 
**TODO** it would be nice if other things like `ArrayList` and `LinkedList`
could be mapped to arrays.

## Id wrapper

As we discussed when talking about object identity,
when a Ceylon instance is serialized to a JSON object we can always use a JSON 
property to attach the instance's identity:

    {
      "#":123,
      ... // the rest of the instances state
    }

but this is not possible when the 
Ceylon instance is serialized to a JSON *array*, because in JSON syntax arrays 
only contain elements. (Note how we don't need to 
worry about things which serialize to JSON strings, numbers, true, false or 
null, because none of the Ceylon values which map to these things are 
`Identifiable`).

Several classes serialize to a JSON array:

* All subclasses of `Sequence`,
* `Array`s

The `Sequence`s are not a problem because they're not `Identifiable`, so if 
two distinct but equal `Sequence`s of the same type get serialized and upon 
deserialization are represented by a single instance there's no way that can 
alter program semantics.

Arrays *are* `Identifiable`, however, so we might need to encode their 
identity.

We use an "identity wrapper":

    {
      "#":567,
      "value":["hello", "world"]
    }

That's the serialized form for an array `Array("hello", "world")`. 

We only use such identity wrappers where we have to (that is, when the array 
is referenced more than once).

## Collections with identity-referencing elements

And what about a collection element referencing an instance by identity? 
Well for that we also use a wrapper JSON object:

    [{"@": 456}]
    
The above example might be emitted when a an `Array` contains a single 
element that's already been emitted in the serialized form and was given id
456.
 
