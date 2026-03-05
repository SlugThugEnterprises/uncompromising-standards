Indestructible Rust: Coding Standard Reference

1. Structural Integrity & Core Safety

Balance: Braces {}, parentheses (), and brackets [] must match perfectly. Structural imbalances often mask deeper logic errors or incomplete refactors that lead to unpredictable parser behavior.

Generics: Angle brackets <> must be balanced in all type-heavy contexts. Complex nested generics must remain legible to ensure that type constraints are mathematically sound and verifiable by the compiler.

No Unsafe: Absolute ban on unsafe blocks, transmute, static mut, or UnsafeCell. Any bypass of the borrow checker introduces the possibility of undefined behavior, memory corruption, and race conditions that are unacceptable in life-critical systems.

Forbid Unsafe: The directive #![forbid(unsafe_code)] must be placed at the crate root. This ensures that the restriction is enforced globally and cannot be overridden by individual modules or third-party dependencies.

Trait Objects: Explicit dyn syntax must not contain suspicious parentheses. Clear definition of dynamic dispatch prevents ambiguity in method resolution and ensures vtable stability.

2. Memory & Allocation (The "No-Heap" Rule)

Prohibit std: Use #![no_std] to ensure zero reliance on an underlying Operating System or hidden, non-deterministic allocations. This forces the software to interact directly with hardware or a minimal, validated abstraction layer.

Ban alloc: Total prohibition of dynamic memory allocation, specifically blocking Vec, Box, HashMap, and Arc. By eliminating the heap, you remove the possibility of memory leaks, fragmentation, or runtime allocation failures.

Fixed Size: All data structures must have a fixed, maximum size known at compile-time. This allows for a precise calculation of the system's memory footprint, ensuring that the hardware is never over-provisioned.

Stack Bounds: Prohibit recursion in all forms. Recursive calls make stack depth non-deterministic; instead, use bounded iterations to ensure the Maximum Stack Usage is constant and verifiable before the device is deployed.

3. Arithmetic & Logic (The "No-Panic" Rule)

Operator Ban: Prohibit the use of standard arithmetic operators +, -, *, /, and %. These operators are "panic-points" because they do not handle overflow or division-by-zero safely by default.

Explicit Arithmetic: Use .checked_, .saturating_, or .wrapping_ methods exclusively. For example, a.saturating_add(b) ensures that even in extreme edge cases, the system remains in a safe, predictable state rather than crashing.

No Indexing: Ban direct indexing (e.g., array[i]). Use .get(i) combined with proper error handling, or utilize safe Iterators. This allows the LLVM compiler to mathematically prove bounds safety and optimize performance by removing runtime checks.

Exhaustive Matches: Ban the wildcard (_) in match statements when handling enums. Every possible state must be explicitly named and handled; this ensures that if a new system state is added, the compiler will force the developer to update every logical decision point in the codebase.

4. Execution & Flow Control

Bounded Loops: Every loop, while, or for must have a verifiable termination condition or a hard-coded maximum iteration count. This prevents "infinite loop" hangs and allows for the calculation of the Worst-Case Execution Time (WCET).

No Shadowing: Prohibit variable shadowing within the same scope. Re-using a name (e.g., let x = x.map(...)) can lead to subtle logic errors where a developer assumes they are working with the original data when they are actually using a transformed version.

No Fallbacks: Prohibit unwrap_or() or unwrap_or_else() in production logic. Fallback values often mask underlying system failures; errors must be propagated and handled with intent rather than suppressed with defaults.

Explicit Init: Prohibit Default::default(). Every variable and struct must be initialized with values that are intentional for the specific context, preventing the accidental use of "magic numbers" or zeroed-out states that have no semantic meaning.

5. Clean Code (KISS, YAGNI, DRY)

YAGNI (You Ain't Gonna Need It): Total ban on placeholder functions, unused crates, or "future-proofing" arguments. Code that is not currently satisfying a requirement is dead weight that increases the surface area for potential bugs.

KISS (Keep It Simple, Stupid): Logic must be simple enough for immediate comprehension by any team member. Avoid "clever" tricks, deep trait nesting, or complex macros that obfuscate the actual flow of data.

Naming: No single-letter variables except for standard mathematical or loop conventions: i, j, k, x, y, z, t, s, e, r. All other variables must have descriptive, semantic names that explain their purpose without needing comments.

File Limits: Small files lead to focused logic.

Max File Size: 1MB.

Max File Length: 150 lines.

Max Function Length: 40 lines. If a function exceeds this, it is performing too many responsibilities and must be decomposed.

6. Debugging & Markers (Forbidden Patterns)

No Markers: Strictly block TODO, FIXME, HACK, XXX, or unimplemented!. A codebase containing these markers is considered "incomplete" and is ineligible for production deployment.

No In-Progress: Block todo!() macros. These macros are functionally equivalent to a panic! and have no place in a validated safety-critical binary.

No Debug Prints: Block dbg!(), println!, or eprintln!. Logging must be handled through a formal, deterministic logging trait that does not rely on standard output streams or blocking I/O.

7. Documentation & Traceability

Requirement Mapping: Every function must include a doc-comment link to a specific Requirement ID (e.g., /// @satisfies REQ-101). This ensures that every line of code exists for a documented reason and facilitates safety audits.

Public Docs: All pub items must have a /// doc comment within 3 lines of declaration. Documentation must explain the "why" and "how" of the interface, including any preconditions or invariants.

100% MC/DC Coverage: Modified Condition/Decision Coverage is mandatory. Testing must exercise every logical branch and every possible combination of boolean conditions to prove that the software behaves correctly under all input permutations.
