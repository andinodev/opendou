@tool
class_name AudioSpatialBinaural
extends RefCounted

## Binaural 3D spatializer calculating spherical azimuth/elevation, Interaural Time Delay (ITD), Interaural Level Difference (ILD), and pinna spectral filtering.

const HEAD_RADIUS_M: float = 0.0875 # ~8.75 cm human head radius
const SPEED_OF_SOUND: float = 343.0  # m/s

class BinauralCues:
	var azimuth_deg: float = 0.0      # -180 (Back Left) to 0 (Front) to +180 (Back Right)
	var elevation_deg: float = 0.0    # -90 (Below) to 0 (Horizon) to +90 (Above)
	var distance_m: float = 0.0
	
	# Interaural Time Delay (ITD) in milliseconds
	var left_ear_delay_ms: float = 0.0
	var right_ear_delay_ms: float = 0.0
	
	# Interaural Level Difference (ILD) in dB
	var left_ear_gain_db: float = 0.0
	var right_ear_gain_db: float = 0.0
	
	# Pinna Spectral Filtering Cutoffs (Hz)
	var left_ear_lpf_hz: float = 20000.0
	var right_ear_lpf_hz: float = 20000.0

## Computes binaural spatial cues for a sound source relative to listener transform.
static func calculate_binaural_cues(source_pos: Vector3, listener_transform: Transform3D) -> BinauralCues:
	var cues = BinauralCues.new()
	var rel_pos = listener_transform.affine_inverse() * source_pos
	cues.distance_m = rel_pos.length()
	
	if cues.distance_m <= 0.0001:
		return cues
		
	# Azimuth calculation in horizontal XZ plane
	var norm_xz = Vector2(rel_pos.x, -rel_pos.z).normalized()
	cues.azimuth_deg = rad_to_deg(atan2(norm_xz.x, norm_xz.y)) # -180 to +180 deg
	
	# Elevation calculation in vertical plane
	var horiz_dist = Vector2(rel_pos.x, rel_pos.z).length()
	cues.elevation_deg = rad_to_deg(atan2(rel_pos.y, horiz_dist)) # -90 to +90 deg
	
	# Woodworth Formula for ITD (Max ~0.65 ms)
	var az_rad = absf(deg_to_rad(cues.azimuth_deg))
	var max_itd_sec = (HEAD_RADIUS_M / SPEED_OF_SOUND) * (sin(az_rad) + az_rad)
	var itd_ms = max_itd_sec * 1000.0
	
	if cues.azimuth_deg > 0.0:
		# Sound on Right -> Right ear receives first, Left ear is delayed
		cues.left_ear_delay_ms = itd_ms
		cues.right_ear_delay_ms = 0.0
		
		# Head shadowing (ILD)
		var shadow_factor = sin(az_rad)
		cues.left_ear_gain_db = -8.0 * shadow_factor
		cues.right_ear_gain_db = 0.0
		cues.left_ear_lpf_hz = lerpf(20000.0, 3500.0, shadow_factor)
		cues.right_ear_lpf_hz = 20000.0
	else:
		# Sound on Left -> Left ear receives first, Right ear is delayed
		cues.left_ear_delay_ms = 0.0
		cues.right_ear_delay_ms = itd_ms
		
		# Head shadowing (ILD)
		var shadow_factor = sin(az_rad)
		cues.left_ear_gain_db = 0.0
		cues.right_ear_gain_db = -8.0 * shadow_factor
		cues.left_ear_lpf_hz = 20000.0
		cues.right_ear_lpf_hz = lerpf(20000.0, 3500.0, shadow_factor)
		
	# Rear and Elevation Pinna filtering
	if absf(cues.azimuth_deg) > 90.0:
		# Behind listener -> Subtle high-frequency dip
		var rear_factor = (absf(cues.azimuth_deg) - 90.0) / 90.0
		cues.left_ear_lpf_hz = minf(cues.left_ear_lpf_hz, lerpf(20000.0, 9000.0, rear_factor))
		cues.right_ear_lpf_hz = minf(cues.right_ear_lpf_hz, lerpf(20000.0, 9000.0, rear_factor))
		
	return cues
