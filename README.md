# cereal-ize
BYOND JSON serialization with versioning and type checking

# Note on type checking
All validation checks are done when serializing/deserializing. This may lead to data corruption if you insert an invalid value and only later on try to serialize but fail and discard the data. 

# Note on circular nesting
Cereal-ize does not offer any safety against infinite loops, it is recommended to keep /world/var/loop_checks enabled and to be careful to not have circular nesting within nested datums

# Dynamically created reserved variables and procs
Name | Usage
---  | ---
/datum/json/var/JSON_TYPE_ANNOTATION_* | Used to store information about types of fields
/datum/json/proc/JSON_Migrate_From_Version_* | Used in the versioning/migration system

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
