# Alabama

Alabama is a serialization library for Ceylon. It uses the 
[`ceylon.language.serialization`][SAPI] API to provide idiomatic 
roundtrip serialization to and from [JSON][JSON].

[tl;dr: example](#tldr)

## Features

<table><tbody>
<tr><td>round trip (to JSON and back)</td>  <td>Yes</td></tr> 
<tr><td>readable output</td>                <td>Yes<sup>1</sup></td></tr>
<tr><td>cross-VM (JVM <-> JSON <-> JS)</td> <td>Yes<sup>2</sup></td></td></tr>
<tr><td>identity-preserving</td>            <td>Yes</td></tr>
<tr><td>supports reference cycles</td>      <td>Yes</td></tr>
<tr><td><code>late</code> attributes</td>   <td>Yes</td></tr>
<tr><td>toplevel classes</td>               <td>Yes, obviously</td></tr>
<tr><td>toplevel <code>object</code>s</td>  <td>Yes</td></tr>
<tr><td>member classes</td>                 <td>No</td></tr>
<tr><td>member <code>object</code>s</td>    <td>No</td></tr>
<tr><td>streaming</td>                      <td>Not yet</td></tr>
<tr><td>blazingly fast</td>                 <td>No</td></tr>
<tr><td>compact output</td>                 <td>Not really<sup>3</sup></td></tr>
</tbody></table>

<br/>

<sup>1</sup> Obviously features such as "identity-preserving" require 
we add extra information to the JSON, but we try to do this in an idiomatic way.<br/> 

<sup>2</sup> "JS" meaning Ceylon running on a JS VM, but obviously it's 
JSON so you can have a plain JS client if you want. <br/>

<sup>3</sup> That's what gzip is for ;-)</br>

## Non-goals

Alabama may or may not be the right choice for you, depending on what you're 
trying to achieve.

* You're using an existing JSON-based REST API

    - You'll probably find using `ceylon.json` directly better fits your 
      needs, because Alabama is not very configurable for parsing arbitrary 
      JSON into Ceylon objects.
      
* You're running on the JVM and need interop with Java code

    - Ceylon classes look like Java beans underneath, so libraries like 
      [Jackson][JACK] and [Gson][GSON] should work OK.
      
    - Most Ceylon classes are Java-`Serializable`, so  
      [Java serialization][JSER] if work for you, if you're 
      not tied to JSON
    
* You need "long term persistence"

    - Alabama is still evolving, and does not support schema evolution, so 
      the JSON emitted might change even if your classes do not.

* You're in an all-Ceylon world, or there are no existing consumers for 
  your JSON and you're not super bothered about controlling every aspect of 
  what your JSON looks like
  
    - Alabama is for you

* Speed is the most important thing for you.

    - Alabama prioritises preserving Ceylon semantics. If you need 
      blazingly fast you might be prepared to compromise on that. 

[GSON]: https://github.com/google/gson
[JACK]: https://github.com/FasterXML/jackson
[JSER]: https://docs.oracle.com/javase/tutorial/essential/io/objectstreams.html
[JSON]: https://tools.ietf.org/html/rfc7159
[SAPI]: https://modules.ceylon-lang.org/repo/1/ceylon/language/1.2.0/module-doc/api/index.html

## Example

<a id="tldr" name="tldr"></a>

OK, here's some Ceylon code:

    serializable class Person(first, last, address) {
        shared String first;
        shared String last;
        shared Address address;
    }
    serializable class Address(lines, zip) {
        [String+] lines;
        String zip;
    }
    
    value p = Person {
        first = "Tom";
        last = "Bentley";
        address = Address {
            lines = ["Jackson", "Alabama"]; 
            zip="1234";
        };
    };
    
    String json = serialize(p);
    Person p2 = deserialize<Person>(json);


And in case you're interested, this is what the JSON looks like:

TODO!!!