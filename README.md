# Fixedsizearray
A fixed size array that has a bunch of useful helper functions

# Example

```D
FixedSizeArray!(int, 10) fsa;
assert(fsa.empty);

fsa.insertBack(1);
assert(fsa.front == 1);
assert(fsa.back == 1);
assert(fsa[0] == 1);

fsa.insertFront(0);
assert(fsa.front == 0);
assert(fsa.back == 1);
assert(fsa[0] == 0);
assert(fsa[1] == 1);

int idx = 0;
foreach(it; fsa[0 .. fsa.length]) {
	assert(it == idx);
	++idx;
}

fsa.removeFront();
assert(fsa.front == 1);
assert(fsa.back == 1);
assert(fsa[0] == 1);

fsa.removeBack();
assert(fsa.empty);
```
