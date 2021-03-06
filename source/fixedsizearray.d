module fixedsizearray;

import std.array : back;
import std.experimental.logger;

struct FixedSizeArraySlice(FSA,T, size_t Size) {
	FSA* fsa;
	short low;
	short high;

	pragma(inline, true)
	this(FSA* fsa, short low, short high) {
		this.fsa = fsa;
		this.low = low;
		this.high = high;
	}

	pragma(inline, true)
	@property bool empty() const pure @safe nothrow @nogc {
		return this.low >= this.high;
	}

	pragma(inline, true)
	@property size_t length() pure @safe nothrow @nogc {
		return cast(size_t)(this.high - this.low);
	}

	pragma(inline, true)
	@property ref T front() {
		return (*this.fsa)[cast(size_t)this.low];
	}

	pragma(inline, true)
	@property ref const(T) front() const {
		return (*this.fsa)[cast(size_t)this.low];
	}

	pragma(inline, true)
	@property ref T back() {
		return (*this.fsa)[cast(size_t)(this.high - 1)];
	}

	pragma(inline, true)
	@property ref const(T) back() const {
		return (*this.fsa)[cast(size_t)(this.high - 1)];
	}

	pragma(inline, true)
	void insertBack(S)(auto ref S s) {
		(*this.fsa).insertBack(s);
	}

	/// Ditto
	alias put = insertBack;

	pragma(inline, true)
	ref T opIndex(const size_t idx) {
		return (*this.fsa)[this.low + idx];
	}

	pragma(inline, true)
	void popFront() pure @safe nothrow @nogc {
		++this.low;
	}

	pragma(inline, true)
	void popBack() pure @safe nothrow @nogc {
		--this.high;
	}

	pragma(inline, true)
	@property typeof(this) save() pure @safe nothrow @nogc {
		return this;
	}

	pragma(inline, true)
	@property const(typeof(this)) save() const pure @safe nothrow @nogc {
		return this;
	}

	pragma(inline, true)
	typeof(this) opIndex() pure @safe nothrow @nogc {
		return this;
	}

	pragma(inline, true)
	typeof(this) opIndex(size_t l, size_t h) pure @safe nothrow @nogc {
		return this.opSlice(l, h);
	}

	pragma(inline, true)
	typeof(this) opSlice(size_t l, size_t h) pure @safe nothrow @nogc {
		assert(l <= h);
		return typeof(this)(this.fsa, 
				cast(short)(this.low + l),
				cast(short)(this.low + h)
			);
	}
}

struct FixedSizeArray(T,size_t Size = 32) {
	import std.traits;
	enum ByteCap = T.sizeof * Size;
	align(8) void[ByteCap] store;
	long base;
	long length_;

	/** If `true` no destructor of any element stored in the FixedSizeArray
	  will be called.
	*/
	bool disableDtor;

	pragma(inline, true)
	this(Args...)(Args args) {
		foreach(it; args) {
			static if(isAssignable!(T,typeof(it))) {
				this.insertBack(it);
			}
		}
	}

	pragma(inline, true)
	~this() {
		static if(hasElaborateDestructor!T) {
			if(!this.disableDtor) {
				this.removeAll();
			}
		}
	}

	pragma(inline, true)
	size_t capacity() const @nogc @safe pure nothrow {
		return Size;
	}

	/** This function inserts an `S` element at the back if there is space.
	Otherwise the behaviour is undefined.
	*/
	pragma(inline, true)
	void insertBack(S)(auto ref S t) @trusted if(is(Unqual!(S) == T)) {
		import std.conv : emplace;
		assert(this.length + 1 <= Size);

		*(cast(T*)(&this.store[
			cast(size_t)((this.base + this.length_) % ByteCap)
		])) = t;
		this.length_ += T.sizeof;
	}

	/// Ditto
	pragma(inline, true)
	void insertBack(S)(auto ref S s) @trusted if(!is(Unqual!(S) == T)) {
		import std.traits;
		import std.conv;

		static if((isIntegral!T || isFloatingPoint!T) 
				|| (isSomeChar!T && isSomeChar!S && T.sizeof >= S.sizeof)) 
		{
			this.insertBack!T(cast(T)(s));
		} else static if (isSomeChar!T && isSomeChar!S && T.sizeof < S.sizeof) {
            /* may throwable operation:
             * - std.utf.encode
             */
            // must do some transcoding around here
            import std.utf : encode;
            Unqual!T[T.sizeof == 1 ? 4 : 2] encoded;
            auto len = encode(encoded, s);
			foreach(T it; encoded[0 .. len]) {
				 this.insertBack!T(it);
			}
        } else static if(isAssignable!(T,S)) {
			*(cast(T*)(&this.store[
				cast(size_t)((this.base + this.length_) % ByteCap)
			])) = s;
			this.length_ += T.sizeof;
		} else {
			static assert(false);
		}
	}

	/// Ditto
	pragma(inline, true)
	void insertBack(S)(auto ref S defaultValue, size_t num) {
		for(size_t i = 0; i < num; ++i) {
			this.insertBack(defaultValue);
		}
	}

	///
	pure @safe unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertBack(1337);
		assert(fsa.length == 1);
		assert(fsa[0] == 1337);

		fsa.insertBack(99, 5);

		foreach(it; fsa[1 .. fsa.length]) {
			assert(it == 99);
		}
	}

	/** This function inserts an `S` element at the front if there is space.
	Otherwise the behaviour is undefined.
	*/
	pragma(inline, true)
	void insertFront(S)(auto ref S t) @trusted if(is(Unqual!(S) == T)) {
		import std.conv : emplace;
		import std.stdio;
		assert(this.length + 1 <= Size);

		this.base -= T.sizeof;
		if(this.base < 0) {
			this.base = cast(typeof(this.base))((ByteCap) - T.sizeof);
		}

		*(cast(T*)(&this.store[cast(size_t)this.base])) = t;
		this.length_ += T.sizeof;
	}

	pure @safe unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertFront(1337);
		assert(fsa.length == 1);
		assert(fsa[0] == 1337);
		assert(fsa.front == 1337);
		assert(fsa.back == 1337);

		fsa.removeBack();
		assert(fsa.length == 0);
		assert(fsa.empty);
		fsa.insertFront(1336);

		assert(fsa.length == 1);
		assert(fsa[0] == 1336);
		assert(fsa.front == 1336);
		assert(fsa.back == 1336);
	}

	pure @safe unittest {
		FixedSizeArray!(int,16) fsa;
		for(int i = 0; i < 32; ++i) {
			fsa.insertFront(i);
			assert(fsa.length == 1);
			assert(!fsa.empty);
			assert(fsa.front == i);
			assert(fsa.back == i);
			fsa.removeFront();
			assert(fsa.length == 0);
			assert(fsa.empty);
		}
	}

	pure @safe unittest {
		FixedSizeArray!(int,16) fsa;
		for(int i = 0; i < 32; ++i) {
			fsa.insertFront(i);
			assert(fsa.length == 1);
			assert(!fsa.empty);
			assert(fsa.front == i);
			assert(fsa.back == i);
			fsa.removeBack();
			assert(fsa.length == 0);
			assert(fsa.empty);
		}
	}

	pure @safe nothrow unittest {
		FixedSizeArray!(int,16) fsa;
		for(int i = 0; i < 32; ++i) {
			fsa.insertBack(i);
			assert(fsa.length == 1);
			assert(!fsa.empty);
			assert(fsa.front == i);
			assert(fsa.back == i);
			fsa.removeFront();
			assert(fsa.length == 0);
			assert(fsa.empty);
		}
	}

	/** This function emplaces an `S` element at the back if there is space.
	Otherwise the behaviour is undefined.
	*/
	pragma(inline, true)
	void emplaceBack(Args...)(auto ref Args args) {
		import std.conv : emplace;
		assert(this.length + 1 <= Size);

		emplace(cast(T*)(&this.store[
			cast(size_t)((this.base + this.length_) % ByteCap)]
		), args);
		this.length_ += T.sizeof;
	}

	/** This function removes an element form the back of the array.
	*/
	pragma(inline, true)
	void removeBack() {
		assert(!this.empty);

		static if(hasElaborateDestructor!T) {
			if(!this.disableDtor) {
				static if(hasMember!(T, "__dtor")) {
					this.back().__dtor();
				} else static if(hasMember!(T, "__xdtor")) {
					this.back().__xdtor();
				} else {
					static assert(false);
				}
			}
		}

		this.length_ -= T.sizeof;
	}

	/** This function removes an element form the front of the array.
	*/
	pragma(inline, true)
	void removeFront() {
		assert(!this.empty);

		static if(hasElaborateDestructor!T) {
			if(!this.disableDtor) {
				static if(hasMember!(T, "__dtor")) {
					this.back().__dtor();
				} else static if(hasMember!(T, "__xdtor")) {
					this.back().__xdtor();
				} else {
					static assert(false);
				}
			}
		}

		//this.begin = (this.begin + T.sizeof) % (Size * T.sizeof);
		this.base += T.sizeof;
		if(this.base >= ByteCap) {
			this.base = 0;
		}
		this.length_ -= T.sizeof;
	}

	pure @safe unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertBack(1337);
		assert(fsa.length == 1);
		assert(fsa[0] == 1337);
		
		fsa.removeBack();
		assert(fsa.length == 0);
		assert(fsa.empty);
	}

	/** This function removes all elements from the array.
	*/
	pragma(inline, true)
	void removeAll() {
		while(!this.empty) {
			this.removeBack();
		}
	}

	pure @safe unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertBack(1337);
		fsa.insertBack(1338);
		assert(fsa.length == 2);
		assert(fsa[0] == 1337);
		assert(fsa[1] == 1338);
		
		fsa.removeAll();
		assert(fsa.length == 0);
		assert(fsa.empty);
	}

	pragma(inline, true)
	void remove(ulong idx) {
		import std.stdio;
		if(idx == 0) {
			this.removeFront();
		} else if(idx == this.length - 1) {
			this.removeBack();
		} else {
			for(long i = idx + 1; i < this.length; ++i) {
				this[cast(size_t)(i - 1)] = this[cast(size_t)i];
			}
			this.removeBack();
		}
	}

	unittest {
		FixedSizeArray!(int,16) fsa;
		foreach(i; 0..10) {
			fsa.insertBack(i);
		}
		fsa.remove(1);
		foreach(idx, i; [0,2,3,4,5,6,7,8,9]) {
			assert(fsa[idx] == i);
		}
		fsa.remove(0);
		foreach(idx, i; [2,3,4,5,6,7,8,9]) {
			assert(fsa[idx] == i);
		}
		fsa.remove(7);
		foreach(idx, i; [2,3,4,5,6,7,8]) {
			assert(fsa[idx] == i);
		}
		fsa.remove(5);
		foreach(idx, i; [2,3,4,5,6,8]) {
			assert(fsa[idx] == i);
		}
		fsa.remove(1);
		foreach(idx, i; [2,4,5,6,8]) {
			assert(fsa[idx] == i);
		}
		fsa.remove(0);
		foreach(idx, i; [4,5,6,8]) {
			assert(fsa[idx] == i);
		}
		fsa.remove(0);
		foreach(idx, i; [5,6,8]) {
			assert(fsa[idx] == i);
		}
	}

	/** Access the last or the first element of the array.
	*/
	pragma(inline, true)
	@property ref T back() @trusted {
		assert(!this.empty);
		return *(cast(T*)(&this.store[
			cast(size_t)(this.base + this.length_ - T.sizeof) % ByteCap
		]));
	}

	pragma(inline, true)
	@property ref const(T) back() const @trusted {
		assert(!this.empty);
		return *(cast(T*)(&this.store[
			cast(size_t)(this.base + this.length_ - T.sizeof) % ByteCap
		]));
	}

	/// Ditto
	pragma(inline, true)
	@property ref T front() @trusted {
		assert(!this.empty);
		return *(cast(T*)(&this.store[cast(size_t)this.base]));
	}

	pragma(inline, true)
	@property ref const(T) front() const @trusted {
		assert(!this.empty);
		return *(cast(T*)(&this.store[cast(size_t)this.base]));
	}

	///
	pure @safe unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertBack(1337);
		fsa.insertBack(1338);
		assert(fsa.length == 2);

		assert(fsa.front == 1337);
		assert(fsa.back == 1338);
	}

	/** Use an index to access the array.
	*/
	pragma(inline, true)
	ref T opIndex(const size_t idx) @trusted {
		import std.format : format;
		assert(idx <= this.length, format("%s %s", idx, this.length));
		return *(cast(T*)(&this.store[
				cast(size_t)((this.base + idx * T.sizeof) % ByteCap)
		]));
	}

	/// Ditto
	pragma(inline, true)
	ref const(T) opIndex(const size_t idx) @trusted const {
		import std.format : format;
		assert(idx <= this.length, format("%s %s", idx, this.length));
		return *(cast(const(T)*)(&this.store[
				cast(size_t)((this.base + idx * T.sizeof) % ByteCap)
		]));
	}

	///
	pure @safe unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertBack(1337);
		fsa.insertBack(1338);
		assert(fsa.length == 2);

		assert(fsa[0] == 1337);
		assert(fsa[1] == 1338);
	}

	/// Gives the length of the array.
	pragma(inline, true)
	@property size_t length() const pure @nogc nothrow {
		return cast(size_t)(this.length_ / T.sizeof);
	}

	/// Ditto
	pragma(inline, true)
	@property bool empty() const pure @nogc nothrow {
		return this.length == 0;
	}

	///
	pure @safe nothrow unittest {
		FixedSizeArray!(int,32) fsa;
		assert(fsa.empty);
		assert(fsa.length == 0);

		fsa.insertBack(1337);
		fsa.insertBack(1338);

		assert(fsa.length == 2);
		assert(!fsa.empty);
	}

	pragma(inline, true)
	FixedSizeArraySlice!(typeof(this),T,Size) opSlice() pure @nogc @safe nothrow {
		return FixedSizeArraySlice!(typeof(this),T,Size)(&this, cast(short)0, 
				cast(short)this.length
		);
	}
	
	pragma(inline, true)
	FixedSizeArraySlice!(typeof(this),T,Size) opSlice(const size_t low, 
			const size_t high) 
			pure @nogc @safe nothrow 
	{
		return FixedSizeArraySlice!(typeof(this),T,Size)(&this, cast(short)low, 
				cast(short)high
		);
	}

	pragma(inline, true)
	auto opSlice() pure @nogc @safe nothrow const {
		return FixedSizeArraySlice!(typeof(this),const(T),Size)
			(&this, cast(short)0, cast(short)this.length);
	}
	
	pragma(inline, true)
	auto opSlice(const size_t low, const size_t high) pure @nogc @safe nothrow const 
	{
		return FixedSizeArraySlice!(typeof(this),const(T),Size)
			(&this, cast(short)low, cast(short)high);
	}
}

unittest {
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
}
unittest {
	import exceptionhandling;
	import std.stdio;

	FixedSizeArray!(int, 16) fsa;
	assert(fsa.empty);
	cast(void)assertEqual(fsa.length, 0);

	fsa.insertBack(1);
	assert(!fsa.empty);
	cast(void)assertEqual(fsa.length, 1);
	cast(void)assertEqual(fsa.front, 1);
	cast(void)assertEqual(fsa.back, 1);

	fsa.insertBack(2);
	assert(!fsa.empty);
	cast(void)assertEqual(fsa.length, 2);
	cast(void)assertEqual(fsa.front, 1);
	cast(void)assertEqual(fsa.back, 2);

	fsa.removeFront();
	assert(!fsa.empty);
	cast(void)assertEqual(fsa.length, 1);
	cast(void)assertEqual(fsa.front, 2);
	cast(void)assertEqual(fsa.back, 2);

	fsa.removeBack();
	//writefln("%s %s", fsa.begin, fsa.end);
	assert(fsa.empty);
	cast(void)assertEqual(fsa.length, 0);
}

unittest {
	import std.format;

	FixedSizeArray!(char,64) fsa;
	formattedWrite(fsa[], "%s %s %s", "Hello", "World", 42);
	//assert(cast(string)fsa == "Hello World 42", cast(string)fsa);
}

unittest {
	import exceptionhandling;

	FixedSizeArray!(int,16) fsa;
	auto a = [0,1,2,4,32,64,1024,2048,65000];
	foreach(idx, it; a) {
		fsa.insertBack(it);
		assertEqual(fsa.length, idx + 1);
		assertEqual(fsa.back, it);
		for(int i = 0; i < idx; ++i) {
			assertEqual(fsa[i], a[i]);
		}
	}
}

unittest {
	import exceptionhandling;
	import std.traits;
	import std.meta;
	import std.range;
	import std.stdio;
	foreach(Type; AliasSeq!(byte,int,long)) {
		FixedSizeArray!(Type,16) fsa2;
		static assert(isInputRange!(typeof(fsa2[])));
		static assert(isForwardRange!(typeof(fsa2[])));
		static assert(isBidirectionalRange!(typeof(fsa2[])));
		foreach(idx, it; [[0], [0,1,2,3,4], [2,3,6,5,6,21,9,36,61,62]]) {
			FixedSizeArray!(Type,16) fsa;
			foreach(jdx, jt; it) {
				fsa.insertBack(jt);
				//writefln("%s idx %d jdx %d length %d", Type.stringof, idx, jdx, fsa.length);
				cast(void)assertEqual(fsa.length, jdx + 1);
				foreach(kdx, kt; it[0 .. jdx]) {
					assertEqual(fsa[kdx], kt);
				}

				{
					auto forward = fsa[];
					auto forward2 = forward;
					cast(void)assertEqual(forward.length, jdx + 1);
					for(size_t i = 0; i < forward.length; ++i) {
						cast(void)assertEqual(forward[i], it[i]);
						cast(void)assertEqual(forward2.front, it[i]);
						forward2.popFront();
					}
					assert(forward2.empty);

					auto backward = fsa[];
					auto backward2 = backward.save;
					cast(void)assertEqual(backward.length, jdx + 1);
					for(size_t i = 0; i < backward.length; ++i) {
						cast(void)assertEqual(backward[backward.length - i - 1],
								it[jdx - i]
						);

						cast(void)assertEqual(backward2.back, 
								it[0 .. jdx + 1 - i].back
						);
						backward2.popBack();
					}
					assert(backward2.empty);
					auto forward3 = fsa[].save;
					auto forward4 = fsa[0 .. jdx + 1];

					while(!forward3.empty && !forward4.empty) {
						cast(void)assertEqual(forward3.front, forward4.front);
						cast(void)assertEqual(forward3.back, forward4.back);
						forward3.popFront();
						forward4.popFront();
					}
					assert(forward3.empty);
					assert(forward4.empty);
				}

				{
					const(FixedSizeArray!(Type,16))* constFsa;
					constFsa = &fsa;
					auto forward = (*constFsa)[];
					auto forward2 = forward.save;
					cast(void)assertEqual(forward.length, jdx + 1);
					for(size_t i = 0; i < forward.length; ++i) {
						cast(void)assertEqual(cast(int)forward[i], it[i]);
						cast(void)assertEqual(cast(int)forward2.front, it[i]);
						forward2.popFront();
					}
					assert(forward2.empty);

					auto backward = (*constFsa)[];
					auto backward2 = backward.save;
					cast(void)assertEqual(backward.length, jdx + 1);
					for(size_t i = 0; i < backward.length; ++i) {
						cast(void)assertEqual(backward[backward.length - i - 1],
								it[jdx - i]
						);

						cast(void)assertEqual(backward2.back, 
								it[0 .. jdx + 1 - i].back
						);
						backward2.popBack();
					}
					assert(backward2.empty);
					auto forward3 = (*constFsa)[];
					auto forward4 = (*constFsa)[0 .. jdx + 1];

					while(!forward3.empty && !forward4.empty) {
						cast(void)assertEqual(forward3.front, forward4.front);
						cast(void)assertEqual(forward3.back, forward4.back);
						forward3.popFront();
						forward4.popFront();
					}
					assert(forward3.empty);
					assert(forward4.empty);
				}
			}
		}
	}
}

unittest {
	import exceptionhandling;

	int cnt;
	int cnt2;

	struct Foo {
		int* cnt;
		this(int* cnt) { this.cnt = cnt; }
		~this() { if(cnt) { ++(*cnt); } }
	}

	int i = 0;
	for(; i < 1000; ++i) {
		{
			FixedSizeArray!(Foo) fsa;
			fsa.insertBack(Foo(&cnt));
			fsa.insertBack(Foo(&cnt));
			fsa.insertBack(Foo(&cnt));
			fsa.insertBack(Foo(&cnt));
		}

		cast(void)assertEqual(cnt, 8 * i + 8);

		{
			FixedSizeArray!(Foo) fsa;
			fsa.emplaceBack(&cnt2);
			fsa.emplaceBack(&cnt2);
			fsa.emplaceBack(&cnt2);
			fsa.emplaceBack(&cnt2);
		}
		cast(void)assertEqual(cnt2, 4 * i + 4);
	}
}

// Test case Issue #2
unittest {
	import exceptionhandling;

	FixedSizeArray!(int,2) fsa;
	fsa.insertBack(0);
	fsa.insertBack(1);

	assertEqual(fsa[0], 0);	
	assertEqual(fsa[1], 1);	
	assertEqual(fsa.front, 0);
	assertEqual(fsa.back, 1);
}

unittest {
	import exceptionhandling;
	import std.stdio;
	string s = "Hellö Wärlß";
	{
		FixedSizeArray!(char,32) fsa;
		foreach(dchar c; s) {
			fsa.insertBack(c);
		}
		for(int i = 0; i < s.length; ++i) {
			assert(fsa[i] == s[i]);
		}
	}
	{
		import std.format;
		FixedSizeArray!(char,32) fsa;
		formattedWrite(fsa[], s);
		for(int i = 0; i < s.length; ++i) {
			assert(fsa[i] == s[i]);
		}
	}
}

unittest {
	import std.stdio;
	import core.memory;
	enum size = 128;
	auto arrays = new FixedSizeArray!(int, size)[size];
	GC.removeRoot(arrays.ptr);
	//FixedSizeArray!(int, size)[size] arrays;
	foreach (i; 0..size) {
	    foreach (j; 0..size) {
			assert(arrays[i].length == j);
	        arrays[i].insertBack(i * 1000 + j);
	    }
	}
	/*foreach(ref it; arrays) {
		writef("%d ", it.length);
	}
	writeln();*/
	bool[int] o;
	foreach (i; 0..size) {
	    foreach (j; 0..size) {
			assert(arrays[i][j] !in o);
	        o[arrays[i][j]] = true;
	    }
	}
	assert(size * size == o.length);
}

// issue #1 won't fix not sure why
unittest {
	import std.stdio;
	import core.memory;
	enum size = 256;
	auto arrays = new FixedSizeArray!(Object,size)();
	//FixedSizeArray!(Object, size) arrays;
	foreach (i; 0..size) {
		auto o = new Object();
		assert(arrays.length == i);
		foreach(it; (*arrays)[]) {
			assert(it !is null);
			assert(it.toHash());
		}
	    arrays.insertBack(o);
		assert(arrays.back is o);
		assert(!arrays.empty);
		assert(arrays.length == i + 1);
	}

	assert(arrays.length == size);
	for(int i = 0; i < size; ++i) {
		assert((*arrays)[i] !is null);
		assert((*arrays)[i].toHash());
	}
	bool[Object] o;
	foreach (i; 0..size) {
		assert((*arrays)[i] !is null);
		assert((*arrays)[i] !in o);
	    o[(*arrays)[i]] = true;
	    
	}
	assert(size == o.length);
}

unittest {
	import exceptionhandling;
	FixedSizeArray!(int,16) fsa;
	fsa.insertFront(1337);
	assert(!fsa.empty);
	assertEqual(fsa.length, 1);
	assertEqual(fsa.back, 1337);
	assertEqual(fsa.front, 1337);
	assertEqual(fsa.base, 15 * int.sizeof);
}

// Test case Issue #2
unittest {
	enum size = 256;
	auto arrays = new FixedSizeArray!(Object, size * Object.sizeof)[size];
	foreach (i; 0..size) {
	    foreach (j; 0..size) {
	        arrays[i].insertBack(new Object);
	    }
	}
	bool[Object] o;
	foreach (i; 0..size) {
	    foreach (j; 0..size) {
	        o[arrays[i][j]] = true;
	    }
	}
	assert(o.length == size * size);
}

unittest {
	import exceptionhandling;
	struct Foo {
		int* a;
		this(int* a) {
			this.a = a;
		}
		~this() {
			if(this.a !is null) {
				++(*a);
			}
		}
	}

	{
		int a = 0;
		{
			FixedSizeArray!(Foo,16) fsa;
			for(int i = 0; i < 10; ++i) {
				fsa.emplaceBack(&a);
			}
		}
		assertEqual(a, 10);
	}
	{
		int a = 0;
		{
			FixedSizeArray!(Foo,16) fsa;
			fsa.disableDtor = true;
			for(int i = 0; i < 10; ++i) {
				fsa.emplaceBack(&a);
			}
		}
		assertEqual(a, 0);
	}
}

unittest {
	import std.range.primitives : hasAssignableElements, hasSlicing, isRandomAccessRange;
	FixedSizeArray!(int,32) fsa;
	auto s = fsa[];
	static assert(hasSlicing!(typeof(s)));
	static assert(isRandomAccessRange!(typeof(s)));
	static assert(hasAssignableElements!(typeof(s)));
}

unittest {
	import exceptionhandling;

	FixedSizeArray!(int,32) fsa;
	for(int i = 0; i < 32; ++i) {
		fsa.insertBack(i);	
	}

	auto s = fsa[];
	for(int i = 0; i < 32; ++i) {
		assert(s[i] == i);
	}
	s = s[0 .. 33];
	for(int i = 0; i < 32; ++i) {
		assert(s[i] == i);
	}

	auto t = s.save;
	s.popFront();
	for(int i = 0; i < 32; ++i) {
		assert(t[i] == i);
	}

	auto r = t[10, 20];
	for(int i = 10; i < 20; ++i) {
		assertEqual(r[i-10], fsa[i]);
	}

	foreach(ref it; r) {
		it = 0;
	}

	for(int i = 10; i < 20; ++i) {
		assertEqual(r[i-10], 0);
	}
}

unittest {
	FixedSizeArray!(int,32) fsaM;
	for(int i = 0; i < 32; ++i) {
		fsaM.insertBack(i);	
	}

	const(FixedSizeArray!(int,32)) fsa = fsaM;

	auto s = fsa[];
	for(int i = 0; i < 32; ++i) {
		assert(s[i] == i);
	}
	s = s[0 .. 33];
	for(int i = 0; i < 32; ++i) {
		assert(s[i] == i);
	}

	auto t = s.save;
	s.popFront();
	for(int i = 0; i < 32; ++i) {
		assert(t[i] == i);
	}
}

unittest {
	import std.random : Random, uniform;
	import std.format : format;
	struct Data {
		ulong a, b, c, d, e;
	}

	auto rnd = Random(1337);
	FixedSizeArray!(Data,128) a;
	for(size_t i = 0; i < 4096; ++i) {
		Data d;
		d.a = i;
		d.b = i;
		d.c = i;
		d.d = i;
		d.e = i;

		a.insertBack(d);

		int c = uniform(4,10, rnd);
		while(a.length > c) {
			a.removeFront();
		}
		assert(!a.empty);
		assert(a.length <= c, format("%d < %d", a.length, c));

		auto r = a[];
		assert(r.back.a == i);
		assert(r.front.a <= i);

		foreach(it; r[]) {
			assert(it.a <= i);
		}

		auto cr = (*(cast(const(typeof(a))*)(&a)));
		assert(cr.back.a == i);
		assert(cr.front.a <= i);

		auto crr = cr[];
		assert(crr.front.a <= i);
		assert(crr.back.a <= i);
		foreach(it; crr.save) {
			assert(it.a <= i);
		}
	}
}
