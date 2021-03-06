/*

OOShipEntity.h

OOEntity subclass representing a ship, or various other flying things like
cargo pods and stations (a subclass).

Oolite
Copyright (C) 2004-2011 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/

#import "OOEntityWithDrawable.h"
#import "OOPlanetEntity.h"
#import "OOJSPropID.h"
#import "OOTriangle.h"

@class	OOShipClass, OOColor, OOStationEntity, OOWormholeEntity, AI, Octree, OOMesh, OOScript, OOJSScript, OORoleSet, OOShipGroup, OOEquipmentType;

#ifdef OO_BRAIN_AI
@class OOBrain;
#endif

@protocol OOHUDBeaconIcon;


#define MAX_TARGETS						24
#define RAIDER_MAX_CARGO				5
#define MERCHANTMAN_MAX_CARGO			125

#define PIRATES_PREFER_PLAYER			YES

#define TURRET_MINIMUM_COS				0.20f

#define AFTERBURNER_BURNRATE			0.25f
#define AFTERBURNER_NPC_BURNRATE		1.0f

#define CLOAKING_DEVICE_ENERGY_RATE		12.8f
#define CLOAKING_DEVICE_MIN_ENERGY		128
#define CLOAKING_DEVICE_START_ENERGY	0.75f

#define MILITARY_JAMMER_ENERGY_RATE		3
#define MILITARY_JAMMER_MIN_ENERGY		128

#define COMBAT_IN_RANGE_FACTOR			0.035f
#define COMBAT_OUT_RANGE_FACTOR			0.500f
#define COMBAT_WEAPON_RANGE_FACTOR		1.200f
#define COMBAT_JINK_OFFSET				500.0f

#define SHIP_COOLING_FACTOR				1.0f
#define SHIP_INSULATION_FACTOR			0.00175f
#define SHIP_MAX_CABIN_TEMP				256.0f
#define SHIP_MIN_CABIN_TEMP				60.0f
#define EJECTA_TEMP_FACTOR				0.85f
#define DEFAULT_HYPERSPACE_SPIN_TIME	15.0f

#define SUN_TEMPERATURE					1250.0f

#define MAX_ESCORTS						16U
#define ESCORT_SPACING_FACTOR			3.0

#define SHIPENTITY_MAX_MISSILES			32U

#define TURRET_TYPICAL_ENERGY			25.0f
#define TURRET_SHOT_SPEED				2000.0f
#define TURRET_SHOT_DURATION			3.0
#define TURRET_SHOT_RANGE				(TURRET_SHOT_SPEED * TURRET_SHOT_DURATION)
#define TURRET_SHOT_FREQUENCY			(TURRET_SHOT_DURATION * TURRET_SHOT_DURATION * TURRET_SHOT_DURATION / 100.0)

#define NPC_PLASMA_SPEED				1500.0f
#define MAIN_PLASMA_DURATION			5.0
#define NPC_PLASMA_RANGE				(MAIN_PLASMA_DURATION * NPC_PLASMA_SPEED)

#define PLAYER_PLASMA_SPEED				1000.0f
#define PLAYER_PLASMA_RANGE				(MAIN_PLASMA_DURATION * PLAYER_PLASMA_SPEED)

#define TRACTOR_FORCE					2500.0f

#define AIMS_AGGRESSOR_SWITCHED_TARGET	@"AGGRESSOR_SWITCHED_TARGET"

// number of vessels considered when scanning around
#define MAX_SCAN_NUMBER					16

#define BASELINE_SHIELD_LEVEL			128.0f			// Max shield level with no boosters.
#define INITIAL_SHOT_TIME				100.0

#define	MIN_FUEL						0				// minimum fuel required for afterburner use

#define ENTITY_PERSONALITY_MAX			0x7FFFU
#define ENTITY_PERSONALITY_INVALID		0xFFFFU

#define WEAPON_FACING_NONE				0
#define WEAPON_FACING_FORWARD			1
#define WEAPON_FACING_AFT				2
#define WEAPON_FACING_PORT				4
#define WEAPON_FACING_STARBOARD			8


#define ENTRY(label, value) label = value,

typedef enum OOBehaviour
{
	#include "OOBehaviour.tbl"
} OOBehaviour;

#undef ENTRY


typedef enum
{
	WEAPON_NONE						= 0U,
	WEAPON_PLASMA_CANNON			= 1,
	WEAPON_PULSE_LASER				= 2,
	WEAPON_BEAM_LASER				= 3,
	WEAPON_MINING_LASER				= 4,
	WEAPON_MILITARY_LASER			= 5,
	WEAPON_THARGOID_LASER			= 10,
	WEAPON_UNDEFINED
} OOWeaponType;


typedef enum
{
	// Alert conditions are used by player and station entities.
	// NOTE: numerical values are available to scripts and shaders.
	ALERT_CONDITION_DOCKED	= 0,
	ALERT_CONDITION_GREEN	= 1,
	ALERT_CONDITION_YELLOW	= 2,
	ALERT_CONDITION_RED		= 3
} OOAlertCondition;


typedef enum
{
#define DIFF_STRING_ENTRY(label, string) label,
	#include "OOShipDamageType.tbl"
#undef DIFF_STRING_ENTRY
	
	kOOShipDamageTypeDefault = kOODamageTypeEnergy
} OOShipDamageType;


// Methods that must be supported by subentities, regardless of type.
@protocol OOSubEntity

- (void) rescaleBy:(GLfloat)factor;

@end



@interface OOShipEntity: OOEntityWithDrawable <OOSubEntity>
{
@public
	// derived variables
	OOTimeDelta				shot_time;					// time elapsed since last shot was fired
	
	// navigation
	Vector					v_forward, v_up, v_right;	// unit vectors derived from the direction faced
	
	// variables which are controlled by instincts/AI
	Vector					destination;				// for flying to/from a set point
	GLfloat					desired_range;				// range to which to journey/scan
	GLfloat					desired_speed;				// speed at which to travel
	OOBehaviour				behaviour;					// ship's behavioural state
	
	OOBoundingBox			totalBoundingBox;			// records ship configuration
	
@protected
	OOWeakReference			*_primaryTarget;			// for combat or rendezvous
	
	Quaternion				subentityRotationalVelocity;
	
	//scripting
	OOJSScript				*script;
	
	//docking instructions
	NSDictionary			*dockingInstructions;
	
	OOWeakReference			*_lastEscortTarget;			// last target an escort was deployed after
	
	OOColor					*laser_color;
	OOColor					*scanner_display_color1;
	OOColor					*scanner_display_color2;
	
	/*
		The “max” variables here are per-ship-class constants, but are cached
		in the entity for efficiency (although the value of this is
		questionable and should be revisited).
		cruiseSpeed is not constant as it can be adjusted for ships with slow
		escorts.
		-- Ahruman 2011-03-25
	*/
	GLfloat					maxFlightSpeed;				// top speed			(160.0 for player)  (200.0 for fast raider)
	GLfloat					max_flight_roll;			// maximum roll rate	(2.0 for player)	(3.0 for fast raider)
	GLfloat					max_flight_pitch;			// maximum pitch rate   (1.0 for player)	(1.5 for fast raider) also radians/sec for (* turrets *)
	GLfloat					max_flight_yaw;
	GLfloat					cruiseSpeed;				// 80% of top speed
//	GLfloat					max_thrust;					// acceleration
	
	GLfloat					thrust;						// acceleration
	
	// TODO: stick all equipment in a list, and move list from playerEntity to shipEntity. -- Ahruman
	unsigned				military_jammer_active: 1,	// military_jammer
	
							docking_match_rotation: 1,
	
	
							pitching_over: 1,			// set to YES if executing a sharp loop
							reportAIMessages: 1,		// normally NO, suppressing AI message reporting
	
							being_mined: 1,				// normally NO, set to Yes when fired on by mining laser
	
							being_fined: 1,
	
							isHulk: 1,					// This is used to distinguish abandoned ships from cargo
							trackCloseContacts: 1,
	
							isNearPlanetSurface: 1,		// check for landing on planet
							isFrangible: 1,				// frangible => subEntities can be damaged individually
							cloaking_device_active: 1,	// cloaking_device
							cloakPassive: 1,			// cloak deactivates when main weapons or missiles are fired
							cloakAutomatic: 1,			// cloak activates itself automatic during attack
							canFragment: 1,				// Can it break into wreckage?
							suppressExplosion: 1,		// Avoid exploding on death (script hook)
							suppressAegisMessages: 1,	// No script/AI messages sent by -checkForAegis,
							isMissile: 1,				// Whether this was launched by fireMissile (used to track submunitions).
							isUnpiloted: 1,				// Is meant to not have crew
							hasScoopMessage: 1,			// suppress scoop messages when false.
	
	// scripting
							scripted_misjump: 1,
							haveExecutedSpawnAction: 1,
							noRocks: 1,
							_lightsActive: 1;
	
	OOFuelQuantity			fuel;						// witch-space fuel
	GLfloat					fuel_accumulator;
	
	OOCargoQuantity			likely_cargo;				// likely amount of cargo (for merchantmen, this is what is spilled as loot)
	OOCargoQuantity			max_cargo;					// capacity of cargo hold
	OOCargoType				cargo_type;					// if this is scooped, this is indicates contents
	OOCargoFlag				cargo_flag;					// indicates contents for merchantmen
	OOCreditsQuantity		bounty;						// bounty (if any)
	
	GLfloat					energy_recharge_rate;		// recharge rate for energy banks
	
	OOWeaponType			forward_weapon_type;		// type of forward weapon (allows lasers, plasma cannon, others)
	OOWeaponType			aft_weapon_type;			// type of aft weapon (allows lasers, plasma cannon, others)
	GLfloat					weapon_damage;				// energy damage dealt by weapon
	GLfloat					weapon_damage_override;		// custom energy damage dealt by front laser, if applicable
	GLfloat					weaponRange;				// range of the weapon (in meters)
	
	GLfloat					scannerRange;				// typically 25600
	
	unsigned				missiles;					// number of on-board missiles
	unsigned				max_missiles;				// number of missile pylons
	NSString				*_missileRole;
	OOTimeDelta				missile_load_time;			// minimum time interval between missile launches
	OOTimeAbsolute			missile_launch_time;		// time of last missile launch
	
#ifdef OO_BRAIN_AI
	OOBrain					*brain;						// brain controlling ship, could be a character brain or the autopilot
#endif
	AI						*shipAI;					// ship's AI system
	
	OORoleSet				*roleSet;					// Roles a ship can take, eg. trader, hunter, police, pirate, scavenger &c.
	NSString				*primaryRole;				// "Main" role of the ship.
	
	// AI stuff
	Vector					jink;						// x and y set factors for offsetting a pursuing ship's position
	Vector					coordinates;				// for flying to/from a set point
	Vector					reference;					// a direction vector of magnitude 1 (* turrets *)
	NSUInteger				_subIdx;					// serialisation index - used only if this ship is a subentity
	NSUInteger				_maxShipSubIdx;				// serialisation index - the number of ship subentities inside the shipdata
	double					launch_time;				// time at which launched
	double					launch_delay;				// delay for thinking after launch
	
	GLfloat					frustration,				// degree of dissatisfaction with the current behavioural state, factor used to test this
							success_factor;
	
	int						patrol_counter;				// keeps track of where the ship is along a patrol route
	
	NSMutableDictionary		*previousCondition;			// restored after collision avoidance
	
	// derived variables
	float					weapon_recharge_rate;		// time between shots
	int						shot_counter;				// number of shots fired
	double					cargo_dump_time;			// time cargo was last dumped
	
	NSMutableArray			*cargo;						// cargo containers go in here

	OOCommodityType			commodity_type;				// type of commodity in a container
	OOCargoQuantity			commodity_amount;			// 1 if unit is TONNES (0), possibly more if precious metals KILOGRAMS (1)
														// or gem stones GRAMS (2)
	
	// navigation
	GLfloat					flightSpeed;				// current speed
	GLfloat					flightRoll;					// current roll rate
	GLfloat					flightPitch;				// current pitch rate
	GLfloat					flightYaw;					// current yaw rate
	
	float					accuracy;
	float					pitch_tolerance;
	
	OOAegisStatus			aegis_status;				// set to YES when within the station's protective zone

	
	double					messageTime;				// counts down the seconds a radio message is active for
	
	double					next_spark_time;			// time of next spark when throwing sparks
	
	Vector					collision_vector;			// direction of colliding thing.
	
	//position of gun ports
	Vector					forwardWeaponOffset,
							aftWeaponOffset,
							portWeaponOffset,
							starboardWeaponOffset;
	
	// crew (typically one OOCharacter - the pilot)
	NSArray					*crew;
	
	// close contact / collision tracking
	NSMutableDictionary		*closeContactsInfo;
	
	NSString				*lastRadioMessage;
	
	// scooping...
	Vector					tractor_position;
	
	// from player entity moved here now we're doing more complex heat stuff
	float					ship_temperature;
	
	// for advanced scanning etc.
	OOShipEntity*				scanned_ships[MAX_SCAN_NUMBER + 1];
	OOScalar				distance2_scanned_ships[MAX_SCAN_NUMBER + 1];
	unsigned				n_scanned_ships;
	
	// advanced navigation
	Vector					navpoints[32];
	unsigned				next_navpoint_index;
	unsigned				number_of_navpoints;
	
	// Collision detection
	Octree					*octree;
	
#ifndef NDEBUG
	// DEBUGGING
	OOBehaviour				debugLastBehaviour;
#endif
	
	uint16_t				entity_personality;			// Per-entity random number. Exposed to shaders and scripts.
	NSDictionary			*scriptInfo;				// script_info dictionary from shipdata.plist, exposed to scripts.
	
	NSMutableArray			*subEntities;
	OOEquipmentType			*missile_list[SHIPENTITY_MAX_MISSILES];
	
	OOShipClass				*_shipClass;				// Should be private, but is mutated by nasty player ship-buying code.
	
@private
	NSDictionary			*_shipInfoDictionary;
	NSString				*_displayName;				// name shown on screen
	
	OOWeakReference			*_subEntityTakingDamage;	//	frangible => subEntities can be damaged individually
	
	NSMutableSet			*_equipment;
	float					_heatInsulation;
	
	OOWeakReference			*_lastAegisLock;			// remember last aegis planet/sun
	
	OOWeakReference			*_foundTarget;				// from scans
	OOWeakReference			*_primaryAggressor;			// recorded after an attack
	OOWeakReference			*_targetStation;			// for docking
	OOWeakReference			*_proximateShip;			// a ship within 2x collision_radius
	OOWeakReference			*_thankedShip;				// last ship thanked
	
	OOShipGroup				*_group;
	OOShipGroup				*_escortGroup;
	uint8_t					_maxEscortCount;
	uint8_t					_pendingEscortCount;
	// Cache of ship-relative positions, managed by -coordinatesForEscortPosition:.
	Vector					_escortPositions[MAX_ESCORTS];
	BOOL					_escortPositionsValid;
	
	GLfloat					_profileRadius;
	
	OOWeakReference			*_shipHitByLaser;			// entity hit by the last laser shot
	
	// beacons
	NSString				*_beaconCode;
	OOWeakReference			*_nextBeacon;
	id <OOHUDBeaconIcon>	_beaconDrawable;
}

- (id)initWithKey:(NSString *)key;
- (id)initWithKey:(NSString *)key definition:(NSDictionary *)dict DEPRECATED_FUNC;

- (OOShipClass *) shipClass;

- (NSString *) name;
- (NSString *) displayName;
- (void) setDisplayName:(NSString *)inName;

// ship brains
- (void) setStateMachine:(NSString *)ai_desc;
- (void) setAI:(AI *)ai;
- (AI *) getAI;
- (void) setShipScript:(NSString *)script_name;
- (void) removeScript;
- (OOScript *) shipScript;
- (double) frustration;
- (void) setLaunchDelay:(double)delay;

- (void) interpretAIMessage:(NSString *)message;

#ifdef OO_BRAIN_AI
- (OOBrain *)brain;
- (void)setBrain:(OOBrain*) aBrain;
#endif

- (OOMesh *)mesh;
- (void)setMesh:(OOMesh *)mesh;

- (Vector) forwardVector;
- (Vector) upVector;
- (Vector) rightVector;

- (NSArray *)subEntities;
- (unsigned) subEntityCount;
- (BOOL) hasSubEntity:(OOEntity<OOSubEntity> *)sub;

- (NSEnumerator *)subEntityEnumerator;
- (NSEnumerator *)shipSubEntityEnumerator;
- (NSEnumerator *)flasherEnumerator;
- (NSEnumerator *)exhaustEnumerator;

- (OOShipEntity *) subEntityTakingDamage;
- (void) setSubEntityTakingDamage:(OOShipEntity *)sub;

- (void) clearSubEntities;	// Releases and clears subentity array, after making sure subentities don't think ship is owner.

// subentities management
- (NSString *) serializeShipSubEntities;
- (void) deserializeShipSubEntitiesFrom:(NSString *)string;
- (NSUInteger) maxShipSubEntities;
- (void) setSubIdx:(NSUInteger)value;
- (NSUInteger) subIdx;

- (Octree *) octree;
- (float) volume;

// octree collision hunting
- (GLfloat)doesHitLine:(Vector) v0: (Vector) v1;
- (GLfloat)doesHitLine:(Vector) v0: (Vector) v1 :(OOShipEntity**) hitEntity;
- (GLfloat)doesHitLine:(Vector) v0: (Vector) v1 withPosition:(Vector) o andIJK:(Vector) i :(Vector) j :(Vector) k;	// for subentities

- (OOBoundingBox) findBoundingBoxRelativeToPosition:(Vector)opv InVectors:(Vector) _i :(Vector) _j :(Vector) _k;

- (Vector)absoluteTractorPosition;

// beacons
- (NSString *) beaconCode;
- (void) setBeaconCode:(NSString *)bcode;
- (BOOL) isBeacon;
- (id <OOHUDBeaconIcon>) beaconDrawable;
- (OOShipEntity *) nextBeacon;
- (void) setNextBeacon:(OOShipEntity*) beaconShip;

- (void) setIsBoulder:(BOOL)flag;
- (BOOL) isBoulder;

- (BOOL) countsAsKill;

- (void) setUpEscorts;
- (void) updateEscortFormation;

- (BOOL)setUpSubEntities;

- (NSString *) shipDataKey;

- (NSDictionary *)shipInfoDictionary DEPRECATED_FUNC;

//- (void) setDefaultWeaponOffsets;

- (BOOL) isFrangible;
- (BOOL) suppressFlightNotifications;

- (void) respondToAttackFrom:(OOEntity *)from becauseOf:(OOEntity *)other;

// Equipment
- (BOOL) hasEquipmentItem:(id)equipmentKeys includeWeapons:(BOOL)includeWeapons;	// This can take a string or an set or array of strings. If a collection, returns YES if ship has _any_ of the specified equipment. If includeWeapons is NO, missiles and primary weapons are not checked.
- (BOOL) hasEquipmentItem:(id)equipmentKeys;			// Short for hasEquipmentItem:foo includeWeapons:NO
- (BOOL) hasAllEquipment:(id)equipmentKeys includeWeapons:(BOOL)includeWeapons;		// Like hasEquipmentItem:includeWeapons:, but requires _all_ elements in collection.
- (BOOL) hasAllEquipment:(id)equipmentKeys;				// Short for hasAllEquipment:foo includeWeapons:NO
- (BOOL) canAddEquipment:(NSString *)equipmentKey;		// Test ability to add equipment, taking equipment-specific constriants into account. 
- (BOOL) equipmentValidToAdd:(NSString *)equipmentKey;	// Actual test if equipment satisfies validation criteria.
- (BOOL) addEquipmentItem:(NSString *)equipmentKey;
- (BOOL) addEquipmentItem:(NSString *)equipmentKey withValidation:(BOOL)validateAddition;

- (BOOL) hasHyperspaceMotor;
- (OOTimeDelta) hyperspaceMotorSpinTime;

- (NSEnumerator *) equipmentEnumerator;
- (unsigned) equipmentCount;
- (void) removeEquipmentItem:(NSString *)equipmentKey;
- (void) removeAllEquipment;
- (OOEquipmentType *) selectMissile;
- (int) removeMissiles;

// Internal, subject to change. Use the methods above instead.
- (BOOL) hasOneEquipmentItem:(NSString *)itemKey includeMissiles:(BOOL)includeMissiles;
- (BOOL) hasPrimaryWeapon:(OOWeaponType)weaponType;
- (BOOL) removeExternalStore:(OOEquipmentType *)eqType;

- (OOWeaponType) forwardWeaponType;
- (OOWeaponType) aftWeaponType;


// Passengers - not supported for NPCs, but interface is here for genericity.
- (unsigned) passengerCount;
- (unsigned) passengerCapacity;

- (unsigned) missileCount;
- (unsigned) missileCapacity;

- (unsigned) extraCargo;

// Tests for the various special-cased equipment items
- (BOOL) hasScoop;
- (BOOL) hasECM;
- (BOOL) hasCloakingDevice;
- (BOOL) hasExpandedCargoBay;
- (BOOL) hasShieldBooster;
- (BOOL) hasMilitaryShieldEnhancer;
- (BOOL) hasHeatShield;
- (BOOL) hasFuelInjection;
- (BOOL) hasCascadeMine;
- (BOOL) hasEscapePod;
- (BOOL) hasDockingComputer;
- (BOOL) hasGalacticHyperdrive;

// Shield information derived from equipment. NPCs can't have shields, but that should change at some point.
- (float) shieldBoostFactor;
- (float) maxForwardShieldLevel;
- (float) maxAftShieldLevel;
- (float) shieldRechargeRate;

- (float) maxHyperspaceDistance;
- (float) afterburnerFactor;
- (float) maxThrust;
- (float) thrust;

// Behaviours
- (void) behaviour_stop_still:(double) delta_t;
- (void) behaviour_idle:(double) delta_t;
- (void) behaviour_tumble:(double) delta_t;
- (void) behaviour_tractored:(double) delta_t;
- (void) behaviour_track_target:(double) delta_t;
- (void) behaviour_intercept_target:(double) delta_t;
- (void) behaviour_attack_target:(double) delta_t;
- (void) behaviour_fly_to_target_six:(double) delta_t;
- (void) behaviour_attack_mining_target:(double) delta_t;
- (void) behaviour_attack_fly_to_target:(double) delta_t;
- (void) behaviour_attack_fly_from_target:(double) delta_t;
- (void) behaviour_running_defense:(double) delta_t;
- (void) behaviour_flee_target:(double) delta_t;
- (void) behaviour_fly_range_from_destination:(double) delta_t;
- (void) behaviour_face_destination:(double) delta_t;
- (void) behaviour_formation_form_up:(double) delta_t;
- (void) behaviour_fly_to_destination:(double) delta_t;
- (void) behaviour_fly_from_destination:(double) delta_t;
- (void) behaviour_avoid_collision:(double) delta_t;
- (void) behaviour_track_as_turret:(double) delta_t;
- (void) behaviour_fly_thru_navpoints:(double) delta_t;

- (GLfloat *) scannerDisplayColorForShip:(OOShipEntity*)otherShip :(BOOL)isHostile :(BOOL)flash :(OOColor *)scannerDisplayColor1 :(OOColor *)scannerDisplayColor2;
- (void)setScannerDisplayColor1:(OOColor *)color1;
- (void)setScannerDisplayColor2:(OOColor *)color2;
- (OOColor *)scannerDisplayColor1;
- (OOColor *)scannerDisplayColor2;

- (BOOL)isCloaked;
- (void)setCloaked:(BOOL)cloak;
- (BOOL)hasAutoCloak;
- (void)setAutoCloak:(BOOL)automatic;

- (void) applyThrust:(double) delta_t;

- (double) messageTime;
- (void) setMessageTime:(double) value;

- (OOShipGroup *) group;
- (void) setGroup:(OOShipGroup *)group;

- (OOShipGroup *) escortGroup;
- (void) setEscortGroup:(OOShipGroup *)group;	// Only for use in unconventional set-up situations.

- (OOShipGroup *) stationGroup; // should probably be defined in stationEntity.m

- (BOOL) hasEscorts;
- (NSEnumerator *) escortEnumerator;
- (NSArray *) escortArray;

- (uint8_t) escortCount;

// Pending escort count: number of escorts to set up "later".
- (uint8_t) pendingEscortCount;
- (void) setPendingEscortCount:(uint8_t)count;

- (OOShipEntity *) proximateShip;
- (void) notePotentialCollsion:(OOShipEntity*) other;

- (NSString *) identFromShip:(OOShipEntity*) otherShip; // name displayed to other ships

- (BOOL) hasRole:(NSString *)role;
- (OORoleSet *)roleSet;

- (void) addRole:(NSString *)role;
- (void) addRole:(NSString *)role withProbability:(float)probability;
- (void) removeRole:(NSString *)role;

- (NSString *)primaryRole;
- (void)setPrimaryRole:(NSString *)role;
- (BOOL)hasPrimaryRole:(NSString *)role;

- (BOOL)isPolice;		// Scan class is CLASS_POLICE
- (BOOL)isThargoid;		// Scan class is CLASS_THARGOID
- (BOOL)isTrader;		// Primary role is "trader" || isPlayer
- (BOOL)isPirate;		// Primary role is "pirate"
- (BOOL)isMissile;		// Primary role has suffix "MISSILE"
- (BOOL)isMine;			// Primary role has suffix "MINE"
- (BOOL)isWeapon;		// isMissile || isWeapon
- (BOOL)isEscort;		// Primary role is "escort"
- (BOOL)isShuttle;		// Primary role is "shuttle"
- (BOOL)isPirateVictim;	// Primary role is listed in pirate-victim-roles.plist
- (BOOL)isUnpiloted;	// Has unpiloted = yes in its shipdata.plist entry

- (BOOL) hasHostileTarget;
- (BOOL) isHostileTo:(OOEntity *)entity;

- (GLfloat) weaponRange;
- (void) setWeaponRange:(GLfloat) value;
- (void) setWeaponDataFromType:(OOWeaponType)weapon_type;
- (float) weaponRechargeRate;
- (void) setWeaponRechargeRate:(float)value;
- (void) setWeaponEnergy:(float)value;

- (GLfloat) scannerRange;
- (void) setScannerRange: (GLfloat) value;

- (Vector) reference;
- (void) setReference:(Vector) v;

- (BOOL) reportAIMessages;
- (void) setReportAIMessages:(BOOL) yn;

- (void) transitionToAegisNone;
- (OOPlanetEntity *) findNearestPlanet;
- (OOEntity<OOStellarBody> *) findNearestStellarBody;		// NOTE: includes sun.
- (OOPlanetEntity *) findNearestPlanetExcludingMoons;
- (OOAegisStatus) checkForAegis;
- (BOOL) isWithinStationAegis;

- (NSArray*) crew;
- (void) setCrew: (NSArray*) crewArray;

// Fuel and capacity in tenths of light-years.
- (OOFuelQuantity) fuel;
- (void) setFuel:(OOFuelQuantity) amount;
- (OOFuelQuantity) fuelCapacity;

- (GLfloat) fuelChargeRate;

- (void) setRoll:(double) amount;
- (void) setPitch:(double) amount;
- (void) setThrust:(double) amount;

- (void)setThrustForDemo:(float)factor;

/*
 Sets the bounty on this ship to amount.  
 Does not check to see if the ship is allowed to have a bounty, for example if it is police.
 */
- (void) setBounty:(OOCreditsQuantity) amount;
- (OOCreditsQuantity) bounty;

- (int) legalStatus;

- (void) setCommodity:(OOCommodityType)co_type andAmount:(OOCargoQuantity)co_amount;
- (void) setCommodityForPod:(OOCommodityType)co_type andAmount:(OOCargoQuantity)co_amount;
- (OOCommodityType) commodityType;
- (OOCargoQuantity) commodityAmount;

- (OOCargoQuantity) maxCargo;
- (OOCargoQuantity) availableCargoSpace;
- (OOCargoQuantity) cargoQuantityOnBoard;
- (OOCargoType) cargoType;
- (NSMutableArray *) cargo;
- (void) setCargo:(NSArray *) some_cargo;
- (BOOL) showScoopMessage;

- (NSArray *) passengerListForScripting;
- (NSArray *) contractListForScripting;
- (NSArray *) equipmentListForScripting;
- (OOEquipmentType *) weaponTypeForFacing:(int) facing;
- (NSArray *) missilesList;

- (OOCargoFlag) cargoFlag;
- (void) setCargoFlag:(OOCargoFlag) flag;

- (void) setSpeed:(double) amount;
- (double) desiredSpeed;
- (void) setDesiredSpeed:(double) amount;

- (double) cruiseSpeed;

- (Vector) thrustVector;
- (void) setTotalVelocity:(Vector)vel;	// Set velocity to vel - thrustVector, effectively setting the instanteneous velocity to vel.

- (void) increase_flight_speed:(double) delta;
- (void) decrease_flight_speed:(double) delta;
- (void) increase_flight_roll:(double) delta;
- (void) decrease_flight_roll:(double) delta;
- (void) increase_flight_pitch:(double) delta;
- (void) decrease_flight_pitch:(double) delta;
- (void) increase_flight_yaw:(double) delta;
- (void) decrease_flight_yaw:(double) delta;

- (GLfloat) flightRoll;
- (GLfloat) flightPitch;
- (GLfloat) flightYaw;
- (GLfloat) flightSpeed;
- (GLfloat) maxFlightSpeed;
- (GLfloat) speedFactor;

- (GLfloat) temperature;
- (void) setTemperature:(GLfloat) value;

- (GLfloat) baseHeatInsulation;
- (void) setBaseHeatInsulation:(GLfloat) value;
- (GLfloat) effectiveHeatInsulation;
- (void) setEffectiveHeatInsulation:(GLfloat)value;

- (float) randomEjectaTemperature;
- (float) randomEjectaTemperatureWithMaxFactor:(float)factor;

// the percentage of damage taken (100 is destroyed, 0 is fine)
- (int) damage;

- (void) dealEnergyDamageWithinDesiredRange;
- (void) dealMomentumWithinDesiredRange:(double)amount;

// Dispatch shipTakingDamage() event.
- (void) noteTakingDamage:(double)amount from:(OOEntity *)entity type:(OOShipDamageType)type;
// Dispatch shipDied() and possibly shipKilledOther() events. This is only for use by getDestroyedBy:damageType:, but needs to be visible to OOPlayerShipEntity's version.
- (void) noteKilledBy:(OOEntity *)whom damageType:(OOShipDamageType)type;

- (void) getDestroyedBy:(OOEntity *)whom damageType:(OOShipDamageType)type;
- (void) becomeExplosion;
- (void) becomeLargeExplosion:(double) factor;
- (void) becomeEnergyBlast;

- (Vector) positionOffsetForAlignment:(NSString*) align;
Vector positionOffsetForShipInRotationToAlignment(OOShipEntity* ship, Quaternion q, NSString* align);

- (void) collectBountyFor:(OOShipEntity *)other;

- (OOBoundingBox) findSubentityBoundingBox;

- (Triangle) absoluteIJKForSubentity;

- (NSComparisonResult) compareBeaconCodeWith:(OOShipEntity *)other;

- (GLfloat)laserHeatLevel;
- (GLfloat)hullHeatLevel;
- (GLfloat)entityPersonality;
- (GLint)entityPersonalityInt;
- (void) setEntityPersonalityInt:(uint16_t)value;

- (void)setSuppressExplosion:(BOOL)suppress;

- (void) resetExhaustPlumes;

/*-----------------------------------------

	AI piloting methods

-----------------------------------------*/

- (void) checkScanner;
- (OOShipEntity**) scannedShips;
- (int) numberOfScannedShips;

- (id) primaryAggressor;
- (void) setPrimaryAggressor:(OOEntity *)targetEntity;
- (void) addTarget:(OOEntity *)targetEntity;
- (void) removeTarget:(OOEntity *)targetEntity;
- (id) primaryTarget;
- (OOUniversalID) primaryTargetID DEPRECATED_FUNC;

- (OOEntity *) lastEscortTarget;

- (OOEntity *) foundTarget;
- (void) setFoundTarget:(OOEntity *)targetEntity;
- (void) announceFoundTarget;	// Sends TARGET_FOUND or NOTHING_FOUND to AI as appropriate.
- (void) setAndAnnounceFoundTarget:(OOEntity *)targetEntity;

- (OOStationEntity *) targetStation;
- (void) setTargetStation:(OOStationEntity *)target;
- (void) setTargetStationAndTarget:(OOStationEntity *)target;

- (OOShipEntity *) thankedShip;
- (void) setThankedShip:(OOShipEntity *)thankedShip;

- (BOOL) isFriendlyTo:(OOShipEntity *)otherShip;

- (OOShipEntity *) shipHitByLaser;

- (void) noteLostTarget;
- (void) noteLostTargetAndGoIdle;
- (void) noteTargetDestroyed:(OOShipEntity *)target;

- (OOBehaviour) behaviour;
- (void) setBehaviour:(OOBehaviour) cond;

- (void) trackOntoTarget:(double) delta_t withDForward: (GLfloat) dp;

- (double) ballTrackTarget:(double) delta_t;
- (double) ballTrackLeadingTarget:(double) delta_t;

- (GLfloat) rollToMatchUp:(Vector) up_vec rotating:(GLfloat) match_roll;

- (GLfloat) rangeToDestination;
- (double) trackDestination:(double) delta_t :(BOOL) retreat;
//- (double) trackPosition:(Vector) track_pos :(double) delta_t :(BOOL) retreat;

- (void) setCoordinate:(Vector)coord;
- (Vector) coordinates;
- (Vector) destination;
- (Vector) distance_six: (GLfloat) dist;
- (Vector) distance_twelve: (GLfloat) dist;

- (double) trackPrimaryTarget:(double) delta_t :(BOOL) retreat;
- (double) missileTrackPrimaryTarget:(double) delta_t;

//return 0.0 if there is no primary target
- (double) rangeToPrimaryTarget;
- (BOOL) onTarget:(BOOL) fwd_weapon;

- (OOTimeDelta) shotTime;
- (void) resetShotTime;

- (BOOL) fireMainWeapon:(double)range;
- (BOOL) fireAftWeapon:(double)range;
- (BOOL) fireTurretCannon:(double)range;
- (void) setLaserColor:(OOColor *)color;
- (OOColor *)laserColor;
- (BOOL) fireSubentityLaserShot:(double)range;
- (BOOL) fireDirectLaserShot;
- (BOOL) fireLaserShotInDirection:(OOViewID)direction;
- (BOOL) firePlasmaShotAtOffset:(double)offset speed:(double)speed color:(OOColor *)color;
- (OOShipEntity *) fireMissile;
- (OOShipEntity *) fireMissileWithIdentifier:(NSString *) identifier andTarget:(OOEntity *) target;
- (BOOL) isMissileFlagSet;
- (void) setIsMissileFlag:(BOOL)newValue;
- (OOTimeDelta) missileLoadTime;
- (void) setMissileLoadTime:(OOTimeDelta)newMissileLoadTime;
- (BOOL) fireECM;
- (void) cascadeIfAppropriateWithDamageAmount:(double)amount cascadeOwner:(OOEntity *)owner;
- (BOOL) activateCloakingDevice;
- (void) deactivateCloakingDevice;
- (BOOL) launchCascadeMine;
- (OOShipEntity *) launchEscapeCapsule;
- (OOCommodityType) dumpCargo;
- (OOShipEntity *) dumpCargoItem;
- (OOCargoType) dumpItem:(OOShipEntity *)jetto;

- (void) manageCollisions;
- (BOOL) collideWithShip:(OOShipEntity *)other;
- (void) adjustVelocity:(Vector) xVel;
- (void) addImpactMoment:(Vector) moment fraction:(GLfloat) howmuch;
- (BOOL) canScoop:(OOShipEntity *)other;
- (void) getTractoredBy:(OOShipEntity *)other;
- (void) scoopIn:(OOShipEntity *)other;
- (void) scoopUp:(OOShipEntity *)other;

- (BOOL) abandonShip;

- (void) takeScrapeDamage:(double) amount from:(OOEntity *) ent;
- (void) takeHeatDamage:(double) amount;

- (void) enterDock:(OOStationEntity *)station;
- (void) leaveDock:(OOStationEntity *)station;

- (void) enterWormhole:(OOWormholeEntity *) wormhole replacing:(BOOL)replacing;
- (void) enterWitchspace;
- (void) leaveWitchspace;
- (void) witchspaceLeavingEffects;

/* 
   Mark this ship as an offender, this is different to setBounty as some ships such as police 
   are not markable.  The final bounty may not be equal to existing bounty plus offence_value.
 */
- (void) markAsOffender:(int)offence_value;

- (void) switchLightsOn;
- (void) switchLightsOff;
- (BOOL) lightsActive;

- (void) setDestination:(Vector) dest;
- (void) setEscortDestination:(Vector) dest;

- (BOOL) canAcceptEscort:(OOShipEntity *)potentialEscort;
- (BOOL) acceptAsEscort:(OOShipEntity *) other_ship;
- (void) deployEscorts;
- (void) dockEscorts;

- (void) setTargetToNearestFriendlyStation;
- (void) setTargetToNearestStation;
- (void) setTargetToSystemStation;

- (void) landOnPlanet:(OOPlanetEntity *)planet;

- (void) abortDocking;

- (void) broadcastThargoidDestroyed;

- (void) broadcastHitByLaserFrom:(OOShipEntity*) aggressor_ship;

// Unpiloted ships cannot broadcast messages, unless the unpilotedOverride is set to YES.
- (void) sendExpandedMessage:(NSString *) message_text toShip:(OOShipEntity*) other_ship;
- (void) sendMessage:(NSString *) message_text toShip:(OOShipEntity*) other_ship withUnpilotedOverride:(BOOL)unpilotedOverride;
- (void) broadcastAIMessage:(NSString *) ai_message;
- (void) broadcastMessage:(NSString *) message_text withUnpilotedOverride:(BOOL) unpilotedOverride;
- (void) setCommsMessageColor;
- (void) receiveCommsMessage:(NSString *) message_text from:(OOShipEntity *) other;
- (void) commsMessage:(NSString *)valueString withUnpilotedOverride:(BOOL)unpilotedOverride;

- (BOOL) markForFines;

- (BOOL) isMining;

- (void) spawn:(NSString *)roles_number;

- (OOShipEntity *) shipBlockingHyperspaceJump;

- (BOOL) trackCloseContacts;
- (void) setTrackCloseContacts:(BOOL) value;

/*
 * Changes a ship to a hulk, for example when the pilot ejects.
 * Aso unsets hulkiness for example when a new pilot gets in.
 */
- (void) setHulk:(BOOL) isNowHulk;
- (BOOL) isHulk;
#if OO_SALVAGE_SUPPORT
- (void) claimAsSalvage;
- (void) sendCoordinatesToPilot;
- (void) pilotArrived;
#endif

- (OOJSScript *)script;
- (NSDictionary *)scriptInfo;

- (BOOL) scriptedMisjump;
- (void) setScriptedMisjump:(BOOL)newValue;

- (OOEntity *)entityForShaderProperties;

/*	*** Script events.
	For NPC ships, these call doEvent: on the ship script.
	For the player, they do that and also call doWorldScriptEvent:.
*/
- (void) doScriptEvent:(jsid)message;
- (void) doScriptEvent:(jsid)message withArgument:(id)argument;
- (void) doScriptEvent:(jsid)message withArgument:(id)argument1 andArgument:(id)argument2;
- (void) doScriptEvent:(jsid)message withArguments:(NSArray *)arguments;
- (void) doScriptEvent:(jsid)message withArguments:(jsval *)argv count:(uintN)argc;
- (void) doScriptEvent:(jsid)message inContext:(JSContext *)context withArguments:(jsval *)argv count:(uintN)argc;

/*	Convenience to send an event with raw JS values, for example:
	ShipScriptEventNoCx(ship, "doSomething", INT_TO_JSVAL(42));
*/
#define ShipScriptEvent(context, ship, event, ...) do { \
	jsval argv[] = { __VA_ARGS__ }; \
	uintN argc = sizeof argv / sizeof *argv; \
	[ship doScriptEvent:OOJSID(event) inContext:context withArguments:argv count:argc]; \
} while (0)

#define ShipScriptEventNoCx(ship, event, ...) do { \
	jsval argv[] = { __VA_ARGS__ }; \
	uintN argc = sizeof argv / sizeof *argv; \
	[ship doScriptEvent:OOJSID(event) withArguments:argv count:argc]; \
} while (0)

- (void) reactToAIMessage:(NSString *)message context:(NSString *)debugContext;	// Immediate message
- (void) sendAIMessage:(NSString *)message;		// Queued message
- (void) doScriptEvent:(jsid)scriptEvent andReactToAIMessage:(NSString *)aiMessage;
- (void) doScriptEvent:(jsid)scriptEvent withArgument:(id)argument andReactToAIMessage:(NSString *)aiMessage;


/*	MARK: Subclass interface
	
	The following methods are intended for subclasses, not clients. If this
	list grows long, we can split it into a separate file.
	-- Ahruman 2011-03-24
*/

/*
	-setUpShipWithShipClass:andDictionary:
	This method performs the complete ship set-up. Subclasses should override
	it as necessary. It’s called by -initWithKey:definition:.
	
	-setUpShipBaseWithShipClass:andDictionary:
	This performs the core OOShipEntity setup that’s shared between players and
	NPCs. OOPlayerShipEntity calls this instead of super setUpShip….
*/

- (BOOL) setUpShipBaseWithShipClass:(OOShipClass *)shipClass andDictionary:(NSDictionary *)shipDict;
- (BOOL) setUpShipWithShipClass:(OOShipClass *)shipClass andDictionary:(NSDictionary *)shipDict;

@end


#ifndef NDEBUG
@interface OOShipEntity (Debug)

- (OOShipGroup *) rawEscortGroup;

@end
#endif


// For the common case of testing whether foo is a ship, bar is a ship, bar is a subentity of foo and this relationship is represented sanely.
@interface OOEntity (SubEntityRelationship)

- (BOOL) isShipWithSubEntityShip:(OOEntity *)other;

@end


NSDictionary *OODefaultShipShaderMacros(void);


// Stuff implemented in OOConstToString.m
enum
{
	// Values used for unknown strings.
	kOOWeaponTypeDefault		= WEAPON_NONE
};

NSString *OOStringFromBehaviour(OOBehaviour behaviour) CONST_FUNC;

// Weapon strings prefixed with EQ_, used in shipyard.plist.
NSString *OOEquipmentIdentifierFromWeaponType(OOWeaponType weapon) CONST_FUNC;
OOWeaponType OOWeaponTypeFromEquipmentIdentifierSloppy(NSString *string) PURE_FUNC;	// Uses suffix match for backwards compatibility.
OOWeaponType OOWeaponTypeFromEquipmentIdentifierStrict(NSString *string) PURE_FUNC;

NSString *OOStringFromWeaponType(OOWeaponType weapon) CONST_FUNC;
OOWeaponType OOWeaponTypeFromString(NSString *string) PURE_FUNC;

NSString *OODisplayStringFromAlertCondition(OOAlertCondition alertCondition);

NSString *OOStringFromShipDamageType(OOShipDamageType type) CONST_FUNC;
