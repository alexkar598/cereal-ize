# Cereal-ize
BYOND JSON serialization with versioning and type checking

# Note on type checking
All validation checks are done when serializing/deserializing. This may lead to data corruption if you insert an invalid value and only later on try to serialize but fail and discard the data. 

# Note on circular nesting
Cereal-ize does not offer any safety against infinite loops, it is recommended to keep /world/var/loop_checks enabled and to be careful to not have circular nesting within nested datums

# Reserved variables and procs
Name | Usage
---  | ---
/var/list/type_info_assoc_list | Global variable used to store type information for all JSON datums
/datum/json/var/JSON_TYPE_ANNOTATION_* | Used to store information about types of fields
/datum/json/proc/JSON_Migrate_From_Version_* | Used in the versioning/migration system
/datum/json/proc/Validate | Used to validate various checks
/datum/json/proc/\_JSON_isValidList | Used to recursively validate simple lists
/datum/json/proc/\_JSON_Deserialize_From_List | Used as an intermediary step in the deserialization process
/datum/json/proc/\_JSON_Serialize_To_List |  Used as an intermediary step in the serialization process
/datum/json/proc/\_is_List_Assoc | Used to check if a list is associative or not

# Basic usage
```dm
//Mode for determining if a list is associative or not, experiment and see which performs better
//Mode 1: Userland code, iterates through list and determines a list as being associative if all values associated to the looped keys are null. Prone to false positives for associative lists where all entries are equal to null
//#define JSON_ASSOC_SCAN_MODE 1
//Mode 2: json_encode(), uses json_encode() and checks if the first character is a [ or a {, 100% reliable but may or may not have a performance cost associated with encoding the entire list to check one character. Blame BYOND
#define JSON_ASSOC_SCAN_MODE 2

//This define will output boolean fields as false/true instead of 0/1
#define JSON_TRUE_BOOLEANS

JSON_DATA(datumid/subid, version)
  //Simple number field, set defaultvalue to the initial value when a datum is created via new without deserializing an object. Note that this does **not** set a default value for undefined fields in the JSON, undefined fields will be deserialized as null. nullable is a boolean (FALSE/TRUE) value which controls if the type checking accepts null as a valid value for serialization/deserialization
  JSON_NUMBER_FIELD(name, defaultvalue, nullable)
  //Simple string field
  JSON_STRING_FIELD(name, defaultvalue, nullable)
  //Simple boolean field, functionally identical to the number field except validation ensures the value is 0 or 1 (FALSE or TRUE)
  JSON_BOOLEAN_FIELD(name, defaultvalue, nullable)
  //Simple list field, keys are restricted to (strings, numbers), values are restricted to (null, strings, numbers, lists which respect these conditions)
  JSON_LIST_FIELD(name, defaultvalue, nullable)
  //Nested json datum, set the second parameter to the id of the nested json datum. Full type checking is available
  JSON_NESTED_FIELD(name, nesteddatumid/nestedsubid, defaultvalue, nullable)
  //List of nested json datums, cannot contain any other value
  JSON_LIST_NESTED_FIELD(name, nesteddatumid/nestedsubid, defaultvalue, nullable)

/world/New()
  . = ..()
  var/datum/json/datumid/subid/json_datum = new
  json_datum.field = value
  var/serialized = json_datum.Serialize()
  if(serialized == FALSE)
    world.log << "Error while serializing: [json_datum.JSON_validation_error]"
    return
  
  var/datum/json/datumid/subid/json_datum2 = new
  if(!json_datum2.Deserialize(serialized))
    world.log << "Error while deserializing: [json_datum2.JSON_validation_error]"
    return
```

# Migrations
Migrations are defined using the `JSON_MIGRATION(datumid, version_from)` syntax

```dm
JSON_DATA(example/migration, 2)
  JSON_NUMBER_FIELD(example_number, null, FALSE)

JSON_MIGRATION(example/migration, 1)
  if(isnum(data["example_number"]))
    data["example_number"] *= 2

/world/New()
  var/datum/json/example/migration/D = new(@|{"example_number": 10}|)
  world.log << D.example_number
  //Expected output: 20
```

# Shortcuts
- The new proc supports a string, a file() object or a path in single quotes ie. 'data.json'. Note that the operation may silently fail if a validation error occurs
- You can use the << operator to deserialize a string, a file() object or a path in single quotes. Ex: `D << 'data.json'`. Note that this operator may create a runtime if a validation error occurs during deserialization.
- You can use the ~ operator to serialize a JSON datum. Ex: `world.log << ~D`. Note that this operator may create a runtime if a validation error occurs during serialization.

# Reference for public members
Identifier|Arguments|Description
   ---    |    ---  | ---
JSON_DATA(PartialPath, Version) | <ul><li>PartialPath: Is appended after /datum/json and serves to identify the JSON datum. Must be valid to put in a path, slashes are allowed.</li><li>Version: Latest version of the JSON datum, used with the versioning/migration system. Must be a number</li></ul> | Used to define a new JSON_DATUM and setup built in variables
JSON_NUMBER_FIELD(Name, DefaultValue, Nullable) | <ul><li>Name: must be a valid variable name, will define a variable by this name</li><li>DefaultValue: Value assigned to this variable when there is nothing deserialized yet. Note that fields missing from deserialized JSON will have null assigned to them.</li><li>Nullable: If the validation should allow this variable to be null or if a value is required to serialize/deserialize</li></ul> | Creates a number JSON field. Must be used in a JSON_DATA() block or in a definition for a /datum/json subtype
JSON_BOOLEAN_FIELD(Name, DefaultValue, Nullable) | See JSON_NUMBER_FIELD | Creates a boolean(number that's either 0 or 1) JSON field. Must be used in a JSON_DATA() block or in a definition for a /datum/json subtype
JSON_STRING_FIELD(Name, DefaultValue, Nullable) | See JSON_NUMBER_FIELD | Creates a text JSON field. Must be used in a JSON_DATA() block or in a definition for a /datum/json subtype
JSON_LIST_FIELD(Name, DefaultValue, Nullable) | See JSON_NUMBER_FIELD | Creates a list JSON field. Keys must be strings or numbers and values must be strings, numbers or null. Must be used in a JSON_DATA() block or in a definition for a /datum/json subtype
JSON_NESTED_FIELD(Name, PartialPath, DefaultValue, Nullable) | <ul><li>PartialPath: must match the PartialPath of the nested JSON datum</li><li>See JSON_NUMBER_FIELD for other parameters</li></ul> | Creates a nested json datum field. Must be used in a JSON_DATA() block or in a definition for a /datum/json subtype.
JSON_LIST_NESTED_FIELD(Name, PartialPath, DefaultValue, Nullable) | <ul><li>PartialPath: must match the PartialPath of the nested JSON datum</li><li>See JSON_NUMBER_FIELD for other parameters</li></ul> | Creates a list of nested json datums field. Must be used in a JSON_DATA() block or in a definition for a /datum/json subtype.
JSON_MIGRATION(PartialPath, Version) | <ul><li>PartialPath: Must match the PartialPath in JSON_DATA()</li><li>Version: Defines the version this migration applies to</li></ul> | This replaces the proc definition, indent and write your migration code. The raw list() will be passed as `data` (see the migration section for an example). This proc will be called automatically if the version of the deserialized json matches the version parameter. **IMPORTANT:** Validation and deserialization of nested datums is done **AFTER** migrations. `data` will contain 100% untrusted user input.
/datum/json/var/JSON_ID | N/A | Matches the PartialPath in the JSON_DATA() definition.
/datum/json/var/JSON_VERSION | N/A | Matches the Version in the JSON_DATA() definition.
/datum/json/var/JSON_validation_error | N/A | Contains the last error raised by the validation process.
/datum/json/var/JSON_include_ID | N/A | Controls if JSON_ID is output in the serialization. Defaults to TRUE.
/datum/json/var/JSON_include_version | N/A | Controls if JSON_VERSION is output in the serialization, required for migrations. Defaults to TRUE.
/datum/josn/var/list/JSON_migrable_versions | N/A | list of versions to call Migrate() on, not required for migrations defined via JSON_MIGRATION(). Defaults to null
/datum/json/proc/New(FileOrText) | <ul><li>FileOrText: Accepts a string, file() object or a single quoted file</li></ul> | Creates a json datum, if FileOrText is defined, will attempt to deseralize it, errors are silently ignored.
/datum/json/proc/Serialize(check_types = TRUE, check_ID = TRUE, check_version = TRUE, check_nullable = TRUE, include_version = null, include_ID = null) | <ul><li>check_types: If field types should be checked, defaults to TRUE</li><li>check_ID: If JSON_ID should be checked, defaults to TRUE</li><li>check_version: If JSON_VERSION should be checked, defaults to TRUE</li><li>check_nullable: If field nullability should be checked, defaults to TRUE.</li><li>include_version: If JSON_VERSION should be included in the output. This option if defined applies recursively to nested datums. Defaults to JSON_include_version of the datum</li><li>include_ID: If JSON_ID should be included in the output. This option if defined applies recursively to nested datums. Defaults to JSON_include_ID of the datum</li></ul> | Serializes a JSON datum, returns a string if successful or FALSE if an error occured(access it via JSON_validation_error). Note that disabling checks may lead to runtime errors.
/datum/json/proc/Deserialize(json, check_types = TRUE, check_ID = TRUE, check_version = TRUE, check_nullable = TRUE, enable_migration = TRUE) | <ul><li>json: JSON string to deserialize. Can also be a file() object or a single quoted file Ex.('data.json'). </li>><li>check_types: If field types should be checked, defaults to TRUE</li><li>check_ID: If JSON_ID should be checked, note that a missing JSON_ID will always pass the check, defaults to TRUE</li><li>check_version: If JSON_VERSION should be checked, note that a missing JSON_VERSION will always pass the check, defaults to TRUE</li><li>check_nullable: If field nullability should be checked, defaults to TRUE.</li><li>enable_migration: Controls if migrations are enabled or if they should be skipped. Can be paired with check_version to disable versioning system completly. Defaults to TRUE.</li></ul> | Deserializes a JSON string, returns TRUE if successful or FALSE if not(error can be accessed via JSON_validation_error). Note that disabling checks may lead to runtime errors.
/datum/json/proc/Migrate(list/data, wanted_version = initial(JSON_VERSION)) | <ul><li>data: output of json_decode, list will be used for the deserialization process. **Important:** This variable contains unvalidated user input. Check all types.</li><li>wanted_version: version to migrate to</li></ul> | This proc should normally not be used or overriden, use JSON_MIGRATION() instead. By default, this proc calls /datum/json/\*/proc/JSON_Migrate_From_Version_\*() for each version until the wanted version is acheived. Note that if you wish to override the migration process, you must increment/edit data["JSON_VERSION"] to reflect the updated version.
/datum/json/proc/operator<<(fileortext) | <ul><li>fileortext: string, file() object or single quoted file to deserialize</li></ul> | `json_datum << files("data.json")` Deserializes JSON. This operator may cause a runtime if a validation error occurs. Usage of Deserialize() with proper error handling is recommended
/datum/json/proc/operator~() | N/A | `world.log << ~json_datum` Serializes a JSON datum. This operator may cause a runtime if a validation error occurs. Usage of Serialize() with proper error handling is recommended
