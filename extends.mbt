// Promotion policy follows moonbitlang/core: `equal` and `to_string` stay
// regular methods; operator derivatives go through the trait.

///|
pub extend InputError with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend InputError with Eq::{not_equal}

///|
pub extend InputError with Show::{to_string}

///|
#deprecated("Use `to_string` instead", skip_current_package=true)
#doc(hidden)
pub extend InputError with Show::{output}
