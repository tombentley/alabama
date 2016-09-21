import ceylon.json {
    Positioned
}
import ceylon.collection {
    LinkedList
}

class Looked<out Item>(item, column, line, position) {
    shared Item item;
    shared Integer column;
    shared Integer line;
    shared Integer position;
    shared actual String string => item?.string else "<null>";
}

//"The type of [[notStarted]]."
shared abstract class NotStarted() of notStarted {}
"A state of [[LookAheadIterator]] when it has not yet consumed any input."
shared object notStarted extends NotStarted() {}

// TODO only shared for testing purposes
"An iterator which supports [[lookAhead]]."
shared class LookAheadIterator<out Item>(Iterator<Item>&Positioned iterator, Integer maxLookAhead) 
        satisfies Iterator<Item>&Positioned {
    
    "Buffer of item from the the iterator, buffer[0] is the last item 
     returned from [[next]]. buffer is empty iff [[next]] has not yet 
     been called."
    LinkedList<Looked<Item>|NotStarted|Finished> buffer = LinkedList<Looked<Item>|NotStarted|Finished>();
    
    Looked<Item>|Finished item(Item|Finished item) {
        if (!is Finished item) {
            return Looked(item, iterator.column, iterator.line, iterator.position);
        } else {
            return finished;
        }
    }
    
    "Look `n` items ahead of the iterators current position.
     
         lookAhead(0) // return same item as the last call to next()
         lookAhead(1) // return item returned by next call to next()
     "
    shared NotStarted|Item|Finished lookAhead(Integer n) {
        assert(0 <= n <= maxLookAhead);
        if (buffer.empty) {
            buffer.add(notStarted);
        }
        while (buffer.size <= n) {
            buffer.add(item(iterator.next()));
        }
        assert(exists l=buffer[n]);
        if (is Looked<Item> l) {
            return l.item;
        } 
        else {
            return l;
        }
    }
    
    "Get the next item in the iterator."
    shared actual Item|Finished next() {
        if (buffer.size > 0) {
            buffer.delete(0);
        }
        if (buffer.size > 0) {
            assert(exists got=buffer.get(0));
            return switch(got) case (is Looked<Anything>) got.item case (is Finished) got else nothing;
        } else {
            value result = item(iterator.next());
            if (is Finished result) {
                buffer.add(finished);
                return finished;
            } else {
                buffer.add(result);
                return result.item;
            }
            
        }
    }
    
    shared actual Integer column => switch(l=buffer.get(0)) case (is Looked<Item>)l.column else -1;
    
    shared actual Integer line => switch(l=buffer.get(0)) case (is Looked<Item>)l.line else -1;
    
    shared actual Integer position => switch(l=buffer.get(0)) case (is Looked<Item>)l.position else -1;
    // TODO
}