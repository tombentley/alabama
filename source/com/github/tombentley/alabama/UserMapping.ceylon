

shared interface StringOutput {
    shared formal void onString(String string);
}

shared interface StringSerializer {
    shared formal Boolean serialize(Object instance, StringOutput output);
    shared formal Object|Null deserialize(String string);
}

