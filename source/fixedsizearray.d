module fixedsizearray;

import std.array : back;
import std.experimental.logger;

import exceptionhandling;

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
	@property bool empty() pure @safe nothrow @nogc {
		return this.low == this.high;
	}

	pragma(inline, true)
	@property size_t length() pure @safe nothrow @nogc {
		return this.high - this.low;
	}

	pragma(inline, true)
	@property ref T front() {
		return (*this.fsa)[this.low];
	}

	pragma(inline, true)
	@property ref T back() {
		return (*this.fsa)[this.high - 1];
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
}

struct FixedSizeArray(T,size_t Size = 32) {
	import std.traits;
	long begin;
	long end;

	/** If `true` no destructor of any element stored in the FixedSizeArray
	  will be called.
	*/
	bool disableDtor;

	byte[T.sizeof * Size] store;

	pragma(inline, true)
	~this() {
		static if(hasElaborateDestructor!T) {
			if(!this.disableDtor) {
				this.removeAll();
			}
		}
	}

	pragma(inline, true)
	void insertBack(S)(auto ref S t) @trusted if(is(Unqual!(S) == T)) {
		import std.conv : emplace;
		import std.stdio;
		assert(this.length + 1 < Size);

		*(cast(T*)(&this.store[this.end])) = t;
		this.end = (this.end + T.sizeof) % (Size * T.sizeof);
	}

	/// Ditto
	pragma(inline, true)
	void insertBack(S)(auto ref S s) @trusted if(!is(Unqual!(S) == T)) {
		import std.traits;
		import std.conv;

		static if((isIntegral!T || isFloatingPoint!T) 
				|| (isSomeChar!T && isSomeChar!U && T.sizeof >= U.sizeof)) 
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
        } else {
			static assert(false);
		}
	}

	unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertBack(1337);
		assert(fsa.length == 1);
		assert(fsa[0] == 1337);
	}

	pragma(inline, true)
	void insertFront(S)(auto ref S t) @trusted if(is(Unqual!(S) == T)) {
		import std.conv : emplace;
		import std.stdio;
		assert(this.length + 1 < Size);

		this.begin = (this.begin - T.sizeof);
		if(this.begin < 0) {
			this.begin = (T.sizeof * Size) - T.sizeof;
		}

		*(cast(T*)(&this.store[this.begin])) = t;
	}

	unittest {
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

	unittest {
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

	unittest {
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

	unittest {
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

	unittest {
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

	pragma(inline, true)
	void emplaceBack(Args...)(auto ref Args args) {
		import std.conv : emplace;
		assert(this.length + 1 < Size);

		emplace(cast(T*)(&this.store[this.end]), args);
		this.end = (this.end + T.sizeof) % (Size * T.sizeof);
	}

	pragma(inline, true)
	void removeBack() {
		assert(!this.empty);

		static if(hasElaborateDestructor!T) {
			if(!this.disableDtor) {
				this.back().__dtor();
			}
		}

		this.end = this.end - T.sizeof;
		if(this.end < 0) {
			this.end = (Size * T.sizeof) - T.sizeof;
		}
	}

	pragma(inline, true)
	void removeFront() {
		assert(!this.empty);

		static if(hasElaborateDestructor!T) {
			if(!this.disableDtor) {
				this.front().__dtor();
			}
		}

		this.begin = (this.begin + T.sizeof) % (Size * T.sizeof);
	}

	unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertBack(1337);
		assert(fsa.length == 1);
		assert(fsa[0] == 1337);
		
		fsa.removeBack();
		assert(fsa.length == 0);
		assert(fsa.empty);
	}

	pragma(inline, true)
	void removeAll() {
		while(!this.empty) {
			this.removeBack();
		}
	}

	unittest {
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
	long backPos() const @safe pure nothrow @nogc {
		if(this.end == 0) {
			return (Size * T.sizeof) - T.sizeof;
		} else {
			return this.end - T.sizeof;
		}
	}

	pragma(inline, true)
	@property ref T back() @trusted {
		assert(!this.empty);
		return *(cast(T*)(&this.store[this.backPos()]));
	}

	/// Ditto
	pragma(inline, true)
	@property ref T front() @trusted {
		assert(!this.empty);
		return *(cast(T*)(&this.store[this.begin]));
	}

	///
	unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertBack(1337);
		fsa.insertBack(1338);
		assert(fsa.length == 2);

		assert(fsa.front == 1337);
		assert(fsa.back == 1338);
	}

	pragma(inline, true)
	ref T opIndex(const size_t idx) @trusted {
		cast(void)assertLess(idx,  this.length);
		return *(cast(T*)(&this.store[(this.begin + (idx * T.sizeof)) % (Size * T.sizeof)]));
	}

	/// Ditto
	pragma(inline, true)
	ref const(T) opIndex(const size_t idx) @trusted const {
		cast(void)assertLess(idx,  this.length);
		return *(cast(const(T)*)(&this.store[(this.begin + (idx * T.sizeof)) % (Size * T.sizeof)]));
	}

	///
	unittest {
		FixedSizeArray!(int,32) fsa;
		fsa.insertBack(1337);
		fsa.insertBack(1338);
		assert(fsa.length == 2);

		assert(fsa[0] == 1337);
		assert(fsa[1] == 1338);
	}

	pragma(inline, true)
	@property size_t length() const pure @nogc nothrow {
		if(this.end == this.begin) {
			return 0UL;
		}
		if(this.end > this.begin) {
			return (this.end - this.begin) / T.sizeof;
		} else {
			//return (this.end / T.sizeof) + ((Size - this.begin) / T.sizeof);
			const a = (this.end / T.sizeof);
			const b = ((Size * T.sizeof) - this.begin) / T.sizeof;
			return a + b;
		}
	}

	/// Ditto
	pragma(inline, true)
	@property size_t empty() const pure @nogc nothrow {
		return this.begin == this.end;
	}

	///
	unittest {
		FixedSizeArray!(int,32) fsa;
		assert(fsa.empty);
		assert(fsa.length == 0);

		fsa.insertBack(1337);
		fsa.insertBack(1338);

		assert(fsa.length == 2);
		assert(!fsa.empty);
	}

	pragma(inline, true)
	auto opSlice() pure @nogc @safe nothrow {
		return FixedSizeArraySlice!(typeof(this),T,Size)(&this, cast(short)0, 
				cast(short)this.length
		);
	}
	
	pragma(inline, true)
	auto opSlice(const size_t low, const size_t high) pure @nogc @safe nothrow {
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
	auto opSlice(const size_t low, const size_t high) pure @nogc @safe nothrow
			const 
	{
		return FixedSizeArraySlice!(typeof(this),const(T),Size)
			(&this, cast(short)low, cast(short)high);
	}

	pragma(inline, true)
	auto opCast(S)() {
		return cast(S)(this.store[this.begin .. this.end]);
	}

	///
	unittest {
		FixedSizeArray!(char,32) fsa;
		string h = "Hello World";

		foreach(char c; h) {
			fsa.insertBack(c);
		}
	
		assert(cast(string)fsa == h);
	}
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
	assert(cast(string)fsa == "Hello World 42", cast(string)fsa);
}

pure nothrow unittest {
	FixedSizeArray!(int,16) fsa;
	foreach(it; [0,1,2,4,32,64,1024,2048,65000]) {
		fsa.insertBack(it);
		assert(fsa.front() == it);
		assert(fsa.back() == it);
		assert(fsa[0] == it);
		assert(fsa.length == 1);
		assert(!fsa.empty);

		auto s = fsa[];
		assert(s.length == 1);
		assert(!s.empty);
		cast(void)assertEqual(s.front, it);
		cast(void)assertEqual(s.back, it);

		auto sc = s;
		auto sc2 = s;

		s.popFront();
		sc.popBack();
		assert(s.length == 0);
		assert(s.empty);
		assert(sc.length == 0);
		assert(sc.empty);

		sc2.front = 1337;
		cast(void)assertEqual(fsa.front, 1337);
		cast(void)assertEqual(fsa.back, 1337);

		fsa.removeBack();
		assert(fsa.length == 0);
		assert(fsa.empty);
	}
}

unittest {
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
