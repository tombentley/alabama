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
<tr><td><code>Character</code>**</td> <td><code>String></code></td></tr>
</tbody>
</table>

\* infinite and undefined (aka NaN) `Floats` get wrapped in objects
   since they can't be represented as numbers in JSON
** distinguished from a Ceylon `String` by type, using an object wrapper 
   with a `"class"` key if necessary

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

For those cases it's necessary for the producer to be explicit by calling 
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
we might have used `"Person"`, for example. 

Currently the `"class"` key has to be *first* in the JSON object 
so the type information can be used to infer the types of the attributes 
corresponding to other keys. This prevents the need to have to read the 
whole JSON tree into memory before deserialization can start.


# Collections

Ceylon has lots of different "collection"-like 
classes, but JSON has only one, and we want the JSON representation to 
look "natural". So `Array`, `ArraySequence`, `Singleton` and `Tuple` all map 
to JSON array. That creates a problem at deserialization, because when 
confronted with

    [1, "a", true]
    
and no type information we need to know what kind of type to recreate.
 
(Because we know that `Sequential` is covariant, we can cheat a little.
At serialization-time we only need to know the *base type* of the sequence
because at deserialization time we can use the types of the elements
to compute a sequence type, and that computed sequence type is necessarily a 
subtype of what the serialization-time sequence type was. 
This is a variation of the trick that we use for all Tuple types).

**TODO** span and measure map to JSON arrays, but maybe shouldn't 
**TODO** it would be nice if other things like `ArrayList` and `LinkedList`
could be mapped to arrays.


## Identity

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

For objects we can add an extra "#" key to encode the identity:

    {
      "#": 123,
      "first": "Jane",
      "second": "Doe"
    }
    
And when an attribute references an object using its identity (rather than
including it as a sub-object) it uses a key ending with a `@`:

    { 
      "#": 124,
      "first": "John",
      "last": "Doe",
      "manager@": 123
    }
    
In general we can't just say `"manager": 123` because the type of the `manager`
reference might be `Integer|Person`, and then `"manager": 123` is ambiguous.

By default we only emit an instance's identity if 
if that instance is referenced more than once.

## Collections with identity

Firstly note that collections aren't always `Identifiable` (in the Ceylon 
sense). This is true of the `Sequential` classes. Since `[1,2,3]` is 
immutable its identity doesn't matter. 

However, there a plenty of collections with a meaningful identity, including
`Array`, so we still need a way to encode the identity of things which otherwise
would get encoded as plain JSON arrays. To do this we use a wrapper JSON 
object:

    { 
      "#": 456,
      "value": [1, 2, 3]
    }

## Collections with identity-referencing elements

And what about a collection element referencing an instance by identity? 
Well for that we also use a wrapper JSON object:

    [{"@": 456}]
    
