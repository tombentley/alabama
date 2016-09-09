import ceylon.collection {
    HashMap,
    HashSet
}
import ceylon.language.meta {
    annotations
}
import ceylon.language.meta.declaration {
    ValueDeclaration,
    ClassDeclaration,
    ClassOrInterfaceDeclaration
}
import ceylon.language.meta.model {
    ClassModel
}

"Annotation class for [[key]]."
shared final annotation class Key(key) 
        satisfies OptionalAnnotation<Key, ValueDeclaration>{
    shared String key;
}

"""Specifies the name of the key used when writing and reading JSON.
   
   For example the class
   
       class Foo(name) {
           key("firstName")
           shared String name;
       }
       
   Would be serialized with the `name` attribute haing the `firstName` key:
   
    ```
    {
        "firstName": "John";
    } 
   """
see(`function aliasedKey`)
shared annotation Key key(String key) => Key(key);

"Annotation class for [[aliasedKey]]."
shared final annotation class AliasedKey(key) 
        satisfies SequencedAnnotation<AliasedKey, ValueDeclaration>{
    shared String key;
}

"""Specifies an alternative name for an attribute when reading JSON. 
   This can be useful to support attribute renaming while maintaining 
   compatibility with serialized data.
 
   For example the initial version of a class might be:
 
       class Foo(name) {
           shared String name;
       }
     
   And thus might be serialized as:
 
   ```
   { "name": "John" }
   ```
   
   Then we might refactor `Foo`, renaming `name` to `firstName`, but still 
   need to read in old-style JSON:
   
       class Foo(firstName) {
           aliasedKey("name")
           shared String firstName;
       }
       
    
 """
see(`function key`)
shared annotation AliasedKey aliasedKey(String name) => AliasedKey(name);

"Annotation class for [[omittedAttribute]]."
shared final annotation class Omitted() 
        satisfies OptionalAnnotation<Omitted, ValueDeclaration>{
}

"Annotates an attribute which should not be included when writing JSON.
 
 Omitting an attribute genererally means the JSON won't be deserializable
 using the [[Deserializer]], but can be useful when working with other 
 consumers of the JSON."
see(`function ignoredKeys`)
shared annotation Omitted omittedAttribute() => Omitted();// unserializable? ignored? notWritten

"Annotation class for [[includedAttribute]]."
shared final annotation class Included() 
        satisfies OptionalAnnotation<Included, ValueDeclaration>{
}

"Annotates a non-reference (i.e. getter) attribute which should be 
 included when writing JSON.
 
 A non-reference attribute is not needed to reconstruct 
 the instance's state 
 (thus would usually also be included in [[ignoredKeys]]),
 but can be useful when dealing with other consumers of the JSON."
see(`function ignoredKeys`)
shared annotation Included includedAttribute() => Included();

"Annotation class for [[ignoredKeys]]."
shared final annotation class IgnoredKeys(keys) 
        satisfies OptionalAnnotation<IgnoredKeys, ClassDeclaration>{
    shared String[] keys;
}

"Annotation class for [[identifier]]."
shared final annotation class Identifier() 
        satisfies OptionalAnnotation<Identifier, ValueDeclaration>{
}
"Annotates an attribute which forms part of the classes identifier, 
 when a class has an explicit identifier"
shared annotation Identifier identifier() => Identifier();


"Annotation class for [[discriminator]]."
shared final annotation class Discriminator() 
        satisfies OptionalAnnotation<Discriminator, ValueDeclaration>{
}
"Annotates an attribute which forms part of the classes discriminator, 
 when a class has an explicit discriminator."
shared annotation Discriminator discriminator() => Discriminator();

"Lists keys to be ignored when reading JSON. A matching attribute will not be sought."
see(`function omittedAttribute`)
shared annotation IgnoredKeys ignoredKeys(String* keys) => IgnoredKeys(keys);


"Per-class configuration options"
shared class ClassSerialization(clazz, omittedAttributes, ignoredKeys, keys) {
    
    "The class"
    shared ClassDeclaration clazz;
    
    "Attributes of the class which should not be included in the emitted JSON"
    shared Collection<ValueDeclaration> omittedAttributes;
    "Keys which should be ignored during deserialization (when reading JSON)."
    shared Collection<String> ignoredKeys;
    "A map from JSON key name to AttibuteSerialization. 
     A given AttibuteSerialization may be included more than once
     if it has aliases."
    shared Map<String, AttibuteSerialization> keys;
    
     value m = HashMap<ValueDeclaration, AttibuteSerialization>();
     for (as in keys.items) {
         m.put(as.attr, as);
     }
    shared Map<ValueDeclaration, AttibuteSerialization> byAttribute = m;
    String pretty<in Element>(Iterable<Element> c1, Iterable<Element> c2)
            given Element satisfies Object
        => ", ".join(HashSet{*c1} & HashSet{*c2});
    
    if (omittedAttributes.containsAny(keys.items)) {
        throw AssertionError("omitted attributes cannot also be keys: ``pretty(omittedAttributes, keys.items)``");
    }
    if (ignoredKeys.containsAny(keys.keys)) {
        throw AssertionError("ignored keys cannot also be keys: ``pretty(ignoredKeys, keys.keys)``");
    }
    
    // TODO check for dupe aliases and/or keys
}
"Per-attribute configuration options"
shared class AttibuteSerialization(attr, key, aliases) {
    "The attribute"
    shared ValueDeclaration attr;
    "The key used for this attribute when instances of the class are serialized as an object"
    shared String key;
    "Alternate names by which this attribute is known during deserialization."
    shared String[] aliases;
}


shared class Config(
    {<ClassDeclaration->ClassSerialization>*} clas=[]) {
    //HashMap<ValueDeclaration, AttibuteSerialization> attributes = HashMap<ValueDeclaration, AttibuteSerialization>{*attrs};
    HashMap<ClassDeclaration, ClassSerialization> classes = HashMap<ClassDeclaration, ClassSerialization>{*clas};
    
    "Build an [[AttibuteSerialization]] according to the annotations on [[attr].]"
    AttibuteSerialization readAttributes(/*HashMap<String, AttibuteSerialization> usedKeys, */ValueDeclaration attr) {
        String key;
        if (exists k = annotations(`Key`, attr)) {
            key = k.key;
        } else {
            key = attr.name;
        }
        String result;
        //if (!key in usedKeys.keys) {
            result = key;
        /*} else if(!"``attr.container.name``.``key``" in usedKeys.keys){
            result = "``attr.container.name``.``key``";
        } else {
            result = "``attr.container.qualifiedName``.``key``";
        }*/
        //keyNames.add(result);
        String[] aliases;
        if (nonempty a = annotations(`AliasedKey`, attr)) {
            aliases = a*.key;
        } else {
            aliases = [];
        }
        
        return AttibuteSerialization(attr, key, aliases);
    }
     
    
    
    
    "get the configuration for the given attribute"
    shared AttibuteSerialization? attribute(ValueDeclaration a) {
        if (is ClassDeclaration c=a.container) {
            return clazz(c).byAttribute[a];
        }
        return null;
    }
    
    
    function qualifiedKey(ValueDeclaration attribute)
            => "``attribute.container.name``.``attribute.name``";
    
    "A map from member to key name"
    shared Map<String,ValueDeclaration> makeKeyNames({ValueDeclaration*} refs) {
        // This is quite subtle because both super and sub classes could have
        // attributes whose names mask a middle class's attribute
        // but the names must be unique, so we qualify non-shared names
        // iff there would otherwise be a collision
        // it's also possible to have a collision between two shared members
        // in which case we just qualify them both
        
        // But the problem is that this is still ambiguous on deserialization
        // To figure out which value declaration applies for any given key
        // we need knowledge of all the keys in the JSON hash, but that would require buffering
        // the JSON hash, which we really need to avoid.
        HashMap<String,ValueDeclaration> keyNames = HashMap<String,ValueDeclaration>();
        for (attribute in refs) {
            //value referent = ref.key;
            //if (is Member referent) {
            //value attribute = referent.attribute;
            assert (exists configged = this.attribute(attribute));
            String base = configged.key;
            if (exists wasAttr = keyNames.put(base, attribute)) {
                assert(is ClassOrInterfaceDeclaration wasClass = wasAttr.container,
                    is ClassOrInterfaceDeclaration refClass = attribute.container);
                if (wasAttr.shared && attribute.shared
                    || !wasAttr.shared && !attribute.shared) {
                    keyNames.put(qualifiedKey(wasAttr), wasAttr);
                    keyNames.put(qualifiedKey(attribute), attribute);
                } else {
                    ValueDeclaration baseNamedMember = wasAttr.shared then wasAttr  else attribute;
                    ValueDeclaration qualNamedMember = wasAttr.shared then attribute else wasAttr;
                    keyNames.put(base, baseNamedMember);
                    keyNames.put(qualifiedKey(qualNamedMember), qualNamedMember);
                }
            }
        }
        //}
        // Now invert the map
        return keyNames;
    }
    
    "Get the configuration for the given class"
    shared ClassSerialization clazz(ClassDeclaration clazz) {
       if (exists cs = classes[clazz]) {
           return cs;
       } else {
           String[] ignoredKeys;
           if (exists k = annotations(`IgnoredKeys`, clazz)) {
               ignoredKeys = k.keys;
           } else {
               ignoredKeys = [];
           }
           value keys = HashMap<String, AttibuteSerialization>{
               // recurse up inheritance hierarchy
               /*entries=if (exists x=clazz.extendedType) then this.clazz(x.declaration).keys else [];*/
           };
           value omittedAttributes = HashSet<ValueDeclaration>();
           for (attr in clazz.declaredMemberDeclarations<ValueDeclaration>()) {
               value as = readAttributes(/*keys, */attr);
               if (exists other=keys.put(as.key, as)) {
                   throw AssertionError("key ``as.key`` on ``as.attr`` is also used as key/alias on ``other.attr``");
               }
               for (al in as.aliases) {
                   if (exists other=keys.put(al, as)) {
                       throw AssertionError("alias ``as.key`` on ``as.attr`` is also used as key/alias on ``other.attr``");
                   }
               }
               if (attr.annotated<Omitted>()) {
                   omittedAttributes.add(attr);
               }
           }
           value cs = ClassSerialization(clazz, omittedAttributes, ignoredKeys, keys);
           classes.put(clazz, cs);
           return cs;
       }
    }

    
    shared AttibuteSerialization? resolveKey(ClassModel<> clazz, String key) {
        variable ClassDeclaration? cd = clazz.declaration;
        while (exists c=cd) {
            value k = this.clazz(c).keys[key];
            if (exists k) {
                return k;
            }
            cd = c.extendedType?.declaration;
        }
        return null;
    }
}

