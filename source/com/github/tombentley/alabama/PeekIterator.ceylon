import ceylon.json {
    Positioned
}
"An iterator which supports [[peek]]ing."
class PeekIterator<T>(Iterator<T>&Positioned iterator) satisfies Iterator<T>&Positioned{
    variable T|Finished|None peeked = none;
    shared T|Finished peek {
        if (!is None p=peeked) {
            return p;
        } else {
            return peeked = iterator.next();
        }
    }
    shared actual T|Finished next() {
        if (!is None p=peeked) {
            peeked = none;
            return p;
        } else {
            return iterator.next();
        }
    }
    shared actual Integer column => iterator.column;
    
    shared actual Integer line => iterator.line;
    
    shared actual Integer position => iterator.position;
    // TODO
}