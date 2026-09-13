#pragma once

#include <type_traits>
#include <nall/stdint.hpp>

//pull all type traits used by nall from std namespace into nall namespace
//this removes the requirement to prefix type traits with std:: within nall

namespace nall {
  using std::add_const;
  using std::conditional;
  using std::conditional_t;
  using std::decay;
  using std::declval;
  using std::enable_if;
  using std::enable_if_t;
  using std::false_type;
  using std::is_floating_point;
  using std::is_floating_point_v;
  using std::forward;
  using std::initializer_list;
  using std::is_array;
  using std::is_base_of;
  using std::is_base_of_v;
  using std::is_function;
  using std::is_integral;
  using std::is_integral_v;
  using std::is_same;
  using std::is_same_v;
  using std::is_signed;
  using std::is_signed_v;
  using std::is_unsigned;
  using std::is_unsigned_v;
  using std::move;
  using std::nullptr_t;
  using std::remove_extent;
  using std::remove_reference;
  using std::swap;
  using std::true_type;
}

// Upstream reopened std:: here to teach std::is_signed/is_unsigned about __int128 on toolchains
// where the standard library didn't already classify it correctly. Newer libc++ (verified: Xcode
// 26.6's, which this package's iOS CI job compiles against) marks these traits
// _LIBCPP_NO_SPECIALIZATIONS and turns any user specialization into a hard compile error --
// "'is_signed' cannot be specialized" -- while ALSO already answering correctly for __int128 via
// its own compiler-intrinsic implementation (confirmed directly: `static_assert(std::is_signed<
// __int128>::value)` and the unsigned equivalent both compile clean with no specialization at all,
// on both this project's older local libc++ and, by construction, would with or without this
// block). The one-time-necessary specialization became redundant-then-forbidden as libc++
// hardened; removing it changes no traits any code here actually observes.
#if INTMAX_BITS >= 128 && !defined(_LIBCPP_VERSION)
namespace std {
  template<> struct is_signed<int128_t> : true_type {};
  template<> struct is_unsigned<uint128_t> : true_type {};
}
#endif
