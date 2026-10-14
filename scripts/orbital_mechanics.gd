class_name OrbitalMechanics
extends RefCounted

## Precision Two-Body Orbital Mechanics (Patched Conics)
## Implements exact Keplerian conic section math in 64-bit double precision.

# Earth real-world constants:
const EARTH_MU: float = 3.986004418e14        # Standard gravitational parameter (m^3 / s^2)
const EARTH_RADIUS: float = 6371000.0         # Volumetric mean radius (meters)

## Computes complete Keplerian orbital state vectors and orbital elements.
static func calculate_orbit(
	r_vec: Vector3,
	v_vec: Vector3,
	mu: float = EARTH_MU,
	planet_radius: float = EARTH_RADIUS
) -> Dictionary:
	var r: float = r_vec.length()
	var v: float = v_vec.length()
	if r < 1.0 or v < 1e-4:
		return _empty_orbit(r, v, planet_radius)

	# Specific angular momentum: h = r x v
	var h_vec: Vector3 = r_vec.cross(v_vec)
	var h: float = h_vec.length()

	# Specific orbital energy: epsilon = v^2 / 2 - mu / r
	var energy: float = (v * v * 0.5) - (mu / r)

	# Eccentricity vector: e_vec = (v x h) / mu - r_norm
	var r_norm: Vector3 = r_vec / r
	var e_vec: Vector3 = (v_vec.cross(h_vec) / mu) - r_norm
	var e: float = e_vec.length()

	# Semi-major axis: a = -mu / (2 * energy)
	var a: float = 0.0
	if absf(energy) > 1e-9:
		a = -mu / (2.0 * energy)

	# Periapsis & Apoapsis
	var r_p: float = 0.0
	var r_a: float = 0.0
	var pe_alt: float = 0.0
	var ap_alt: float = 0.0
	var period: float = 0.0
	var orbit_type: String = "Elliptical"

	if e < 0.9999: # Elliptical / Circular
		r_p = a * (1.0 - e)
		r_a = a * (1.0 + e)
		pe_alt = r_p - planet_radius
		ap_alt = r_a - planet_radius
		if a > 0.0:
			period = 2.0 * PI * sqrt((a * a * a) / mu)
		orbit_type = "Circular" if e < 0.005 else "Elliptical"
	elif absf(e - 1.0) < 0.001: # Parabolic
		r_p = (h * h) / (2.0 * mu)
		r_a = INF
		pe_alt = r_p - planet_radius
		ap_alt = INF
		period = INF
		orbit_type = "Parabolic"
	else: # Hyperbolic (escape trajectory)
		r_p = a * (1.0 - e) # for a < 0, this is positive
		if r_p < 0.0:
			r_p = absf(a) * (e - 1.0)
		r_a = INF
		pe_alt = r_p - planet_radius
		ap_alt = INF
		period = INF
		orbit_type = "Hyperbolic"

	# Inclination: angle between orbital plane normal (h_vec) and reference pole (+Y)
	var inc_rad: float = 0.0
	if h > 1e-6:
		inc_rad = acos(clampf(h_vec.y / h, -1.0, 1.0))

	# True Anomaly: angle between periapsis vector and position vector
	var true_anomaly: float = 0.0
	if e > 1e-6:
		var cos_nu: float = clampf(e_vec.dot(r_vec) / (e * r), -1.0, 1.0)
		true_anomaly = acos(cos_nu)
		if r_vec.dot(v_vec) < 0.0:
			true_anomaly = 2.0 * PI - true_anomaly

	# Orbital plane reference unit vectors:
	# P = unit vector pointing towards periapsis
	# W = unit normal to orbital plane (h direction)
	# Q = orthogonal in-plane unit vector (W x P)
	var p_unit: Vector3
	if e > 1e-5:
		p_unit = e_vec.normalized()
	else:
		p_unit = r_norm

	var w_unit: Vector3 = h_vec.normalized() if h > 1e-6 else Vector3.UP
	var q_unit: Vector3 = w_unit.cross(p_unit).normalized()

	return {
		"r": r,
		"v": v,
		"energy": energy,
		"semi_major_axis": a,
		"eccentricity": e,
		"eccentricity_vector": e_vec,
		"angular_momentum": h,
		"angular_momentum_vector": h_vec,
		"periapsis_radius": r_p,
		"apoapsis_radius": r_a,
		"periapsis_alt": pe_alt,
		"apoapsis_alt": ap_alt,
		"period": period,
		"inclination_deg": rad_to_deg(inc_rad),
		"true_anomaly_deg": rad_to_deg(true_anomaly),
		"orbit_type": orbit_type,
		"p_unit": p_unit,
		"q_unit": q_unit,
		"w_unit": w_unit,
		"periapsis_pos": p_unit * r_p,
		"apoapsis_pos": -p_unit * r_a if (e < 1.0) else Vector3.ZERO
	}

static func _empty_orbit(r: float, v: float, pr: float) -> Dictionary:
	return {
		"r": r, "v": v, "energy": 0.0, "semi_major_axis": 0.0,
		"eccentricity": 0.0, "eccentricity_vector": Vector3.ZERO,
		"angular_momentum": 0.0, "angular_momentum_vector": Vector3.ZERO,
		"periapsis_radius": r, "apoapsis_radius": r,
		"periapsis_alt": r - pr, "apoapsis_alt": r - pr,
		"period": 0.0, "inclination_deg": 0.0, "true_anomaly_deg": 0.0,
		"orbit_type": "Undefined",
		"p_unit": Vector3.FORWARD, "q_unit": Vector3.RIGHT, "w_unit": Vector3.UP,
		"periapsis_pos": Vector3.ZERO, "apoapsis_pos": Vector3.ZERO
	}

## Generates 3D trajectory points along the conic section relative to planet center.
static func generate_trajectory_points(
	orbit: Dictionary,
	num_points: int = 180
) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var e: float = orbit.get("eccentricity", 0.0)
	var a: float = orbit.get("semi_major_axis", 0.0)
	var p_unit: Vector3 = orbit.get("p_unit", Vector3.FORWARD)
	var q_unit: Vector3 = orbit.get("q_unit", Vector3.RIGHT)

	if p_unit.length_squared() < 0.1 or q_unit.length_squared() < 0.1:
		return pts

	if e < 0.999: # Elliptical / Circular orbit
		var p_param: float = a * (1.0 - e * e)
		if p_param <= 0.0:
			return pts

		pts.resize(num_points + 1)
		for i in range(num_points + 1):
			var theta: float = (float(i) / float(num_points)) * 2.0 * PI
			var cos_t: float = cos(theta)
			var sin_t: float = sin(theta)
			var r_theta: float = p_param / (1.0 + e * cos_t)
			var pos: Vector3 = (p_unit * cos_t + q_unit * sin_t) * r_theta
			pts[i] = pos
	else: # Hyperbolic trajectory
		var theta_inf: float = acos(clampf(-1.0 / max(1.001, e), -1.0, 1.0))
		var max_theta: float = theta_inf * 0.92
		var p_param: float = absf(a) * (e * e - 1.0)
		pts.resize(num_points + 1)
		for i in range(num_points + 1):
			var t: float = float(i) / float(num_points)
			var theta: float = lerpf(-max_theta, max_theta, t)
			var cos_t: float = cos(theta)
			var sin_t: float = sin(theta)
			var r_theta: float = p_param / max(0.01, (1.0 + e * cos_t))
			var pos: Vector3 = (p_unit * cos_t + q_unit * sin_t) * r_theta
			pts[i] = pos

	return pts

## Solves Kepler's Equation M = E - e*sin(E) for Eccentric Anomaly E using Newton-Raphson
static func solve_kepler(M: float, e: float) -> float:
	var E: float = M if e < 0.8 else PI
	for i in range(16):
		var f: float = E - e * sin(E) - M
		var f_prime: float = 1.0 - e * cos(E)
		var delta_e: float = f / max(1e-12, f_prime)
		E -= delta_e
		if absf(delta_e) < 1e-8:
			break
	return E

## Computes initial Mean Anomaly M0 from relative position vector
static func get_mean_anomaly_from_pos(orbit: Dictionary, current_pos_rel: Vector3) -> float:
	var e: float = orbit.get("eccentricity", 0.0)
	var p_unit: Vector3 = orbit.get("p_unit", Vector3.FORWARD)
	var q_unit: Vector3 = orbit.get("q_unit", Vector3.RIGHT)

	var r: float = current_pos_rel.length()
	var r_norm: Vector3 = current_pos_rel / max(1.0, r)
	var cos_nu: float = clampf(p_unit.dot(r_norm), -1.0, 1.0)
	var sin_nu: float = clampf(q_unit.dot(r_norm), -1.0, 1.0)
	var nu: float = atan2(sin_nu, cos_nu)
	if nu < 0.0: nu += 2.0 * PI

	var denom: float = 1.0 + e * cos(nu)
	var cos_E0: float = (e + cos_nu) / max(1e-12, denom)
	var sin_E0: float = sqrt(max(0.0, 1.0 - e * e)) * sin_nu / max(1e-12, denom)
	var E0: float = atan2(sin_E0, cos_E0)
	if E0 < 0.0: E0 += 2.0 * PI

	var M0: float = E0 - e * sin(E0)
	if M0 < 0.0: M0 += 2.0 * PI
	return M0

## Analytically evaluates exact Keplerian state at elapsed time t with zero numerical drift
static func evaluate_orbit_state(orbit: Dictionary, M0: float, elapsed_time: float, mu: float = EARTH_MU) -> Dictionary:
	var a: float = orbit.get("semi_major_axis", 0.0)
	var e: float = orbit.get("eccentricity", 0.0)
	var p_unit: Vector3 = orbit.get("p_unit", Vector3.FORWARD)
	var q_unit: Vector3 = orbit.get("q_unit", Vector3.RIGHT)

	if a <= 0.0 or e >= 0.999:
		return {"pos": Vector3.ZERO, "vel": Vector3.ZERO}

	var n: float = sqrt(mu / (a * a * a))
	var M: float = fmod(M0 + n * elapsed_time, 2.0 * PI)
	if M < 0.0: M += 2.0 * PI

	var E: float = solve_kepler(M, e)
	var cos_E: float = cos(E)
	var sin_E: float = sin(E)
	var r_mag: float = a * (1.0 - e * cos_E)

	var pos: Vector3 = (p_unit * (cos_E - e) + q_unit * (sqrt(max(0.0, 1.0 - e * e)) * sin_E)) * a
	var factor: float = sqrt(mu * a) / max(1.0, r_mag)
	var vel: Vector3 = (-sin_E * p_unit + sqrt(max(0.0, 1.0 - e * e)) * cos_E * q_unit) * factor

	return {"pos": pos, "vel": vel}

## Analytically propagates position and velocity along Keplerian orbit by dt seconds (zero drift)
static func propagate_orbit(orbit: Dictionary, current_pos_rel: Vector3, dt: float, mu: float = EARTH_MU) -> Dictionary:
	var M0: float = get_mean_anomaly_from_pos(orbit, current_pos_rel)
	return evaluate_orbit_state(orbit, M0, dt, mu)

