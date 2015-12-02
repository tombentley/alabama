import ceylon.test {
    test,
    assertEquals
}

import ceylon.json {
    Positioned
}
import com.github.tombentley.alabama {
    LookAheadIterator,
    notStarted
}

test
shared void testLookAhead() {
    class It(Integer max=3) satisfies Iterator<Integer>&Positioned {
        
        variable value n = 0;
        
        shared actual Integer column => n;
        
        shared actual Integer line => n;
        
        shared actual Integer|Finished next() {
            if (n < max) {
                return n++;
            } else {
                return finished;
            }
        }
        
        shared actual Integer position => n;
    }
    
    variable value la = LookAheadIterator(It(), 2);
    assertEquals(la.lookAhead(0), notStarted);
    assertEquals(la.lookAhead(0), notStarted);
    assertEquals(la.lookAhead(0), notStarted);
    assertEquals(la.next(), 0);
    assertEquals(la.lookAhead(0), 0);
    assertEquals(la.lookAhead(0), 0);
    assertEquals(la.next(), 1);
    assertEquals(la.lookAhead(0), 1);
    assertEquals(la.lookAhead(0), 1);
    assertEquals(la.next(), 2);
    assertEquals(la.lookAhead(0), 2);
    assertEquals(la.lookAhead(0), 2);
    assertEquals(la.next(), finished);
    assertEquals(la.lookAhead(0), finished);
    assertEquals(la.lookAhead(0), finished);
    
    la = LookAheadIterator(It(), 2);
    assertEquals(la.lookAhead(0), notStarted);
    assertEquals(la.lookAhead(1), 0);
    assertEquals(la.lookAhead(2), 1);
    assertEquals(la.next(), 0);
    assertEquals(la.lookAhead(0), 0);
    assertEquals(la.lookAhead(1), 1);
    assertEquals(la.next(), 1);
    assertEquals(la.lookAhead(0), 1);
    assertEquals(la.lookAhead(1), 2);
    assertEquals(la.next(), 2);
    assertEquals(la.lookAhead(0), 2);
    assertEquals(la.lookAhead(1), finished);
    assertEquals(la.next(), finished);
    assertEquals(la.lookAhead(0), finished);
    assertEquals(la.lookAhead(1), finished);
    assertEquals(la.lookAhead(0), finished);
    assertEquals(la.lookAhead(1), finished);
    
    la = LookAheadIterator(It(), 1);
    assertEquals(la.lookAhead(0), notStarted);
    assertEquals(la.lookAhead(1), 0);
    try {
        la.lookAhead(2);
        throw;
    } catch (AssertionError e) {
        
    }
    
    la = LookAheadIterator(It(), 5);
    assertEquals(la.lookAhead(0), notStarted);
    assertEquals(la.lookAhead(1), 0);
    assertEquals(la.lookAhead(2), 1);
    assertEquals(la.lookAhead(3), 2);
    assertEquals(la.lookAhead(4), finished);
    assertEquals(la.lookAhead(5), finished);
    assertEquals(la.next(), 0);
    assertEquals(la.next(), 1);
    assertEquals(la.lookAhead(0), 1);
    
    la = LookAheadIterator(It(1), 2);
    assertEquals(la.next(), 0);
    assertEquals(la.next(), finished);
    
    la = LookAheadIterator(It(1), 2);
    assertEquals(la.lookAhead(0), notStarted);
    assertEquals(la.lookAhead(1), 0);
    assertEquals(la.lookAhead(2), finished);
}