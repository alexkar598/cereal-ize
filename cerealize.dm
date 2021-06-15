/*
    Copyright (C) 2021 by alexkar598

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without l> imitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

//type annotation = list(Type, Nullable, Prefix)

#define JSON_TYPE_NUMBER  "num"
#define JSON_TYPE_STRING  "str"
#define JSON_TYPE_BOOLEAN "bool"
#define JSON_TYPE_LIST    "list"
#define JSON_TYPE_NESTED  "nested"
#define JSON_TYPE_LIST_NESTED  "list-nested"
#define JSON_TYPE_ASSOC_LIST_NESTED  "assoc-list-nested"

#define JSON_VALIDATE_MODE_DESERIALIZE "deserialize"
#define JSON_VALIDATE_MODE_SERIALIZE   "serialize"

#define JSON_TYPE_ANNOTATION_TYPE     1
#define JSON_TYPE_ANNOTATION_NULLABLE 2
#define JSON_TYPE_ANNOTATION_PREFIX   3

///Scans through the list and sees if all value lookups are null, if so, assumes its not associative,
/// this breaks on lists such as list("e" = null, "f" = null) and incorrectly reports it as non associative
//#define JSON_ASSOC_SCAN_MODE 1
///100% realiable, uses json_encode to detect if its an associative list
//#define JSON_ASSOC_SCAN_MODE 2

//#define JSON_TRUE_BOOLEANS

#define JSON_TYPED_FIELD(Name, Type, DefaultValue, Nullable) \
    var/static/list/JSON_TYPE_ANNOTATION_##Name = list(Type, Nullable, null)    ; \
    var/##Name = DefaultValue

#define JSON_PREFIXED_TYPED_FIELD(Name, Type, DefaultValue, Nullable, Prefix, RealPrefix) \
    var/static/list/JSON_TYPE_ANNOTATION_##Name = list(Type, Nullable, /##Prefix)    ; \
    var/##RealPrefix/##Name = DefaultValue

#define JSON_NUMBER_FIELD(Name, DefaultValue, Nullable) JSON_TYPED_FIELD(Name, JSON_TYPE_NUMBER, DefaultValue, Nullable)
#define JSON_STRING_FIELD(Name, DefaultValue, Nullable) JSON_TYPED_FIELD(Name, JSON_TYPE_STRING, DefaultValue, Nullable)
#define JSON_BOOLEAN_FIELD(Name, DefaultValue, Nullable) JSON_TYPED_FIELD(Name, JSON_TYPE_BOOLEAN, DefaultValue, Nullable)
#define JSON_LIST_FIELD(Name, DefaultValue, Nullable) JSON_PREFIXED_TYPED_FIELD(Name, JSON_TYPE_LIST, DefaultValue, Nullable, list, list)
#define JSON_NESTED_FIELD(Name, PartialPath, DefaultValue, Nullable) JSON_PREFIXED_TYPED_FIELD(Name, JSON_TYPE_NESTED, DefaultValue, Nullable, datum/json/##PartialPath, datum/json/##PartialPath)
#define JSON_LIST_NESTED_FIELD(Name, PartialPath, DefaultValue, Nullable) JSON_PREFIXED_TYPED_FIELD(Name, JSON_TYPE_LIST_NESTED, DefaultValue, Nullable, datum/json/##PartialPath, list/datum/json/##PartialPath)
#define JSON_ASSOC_LIST_NESTED_FIELD(Name, PartialPath, DefaultValue, Nullable) JSON_PREFIXED_TYPED_FIELD(Name, JSON_TYPE_ASSOC_LIST_NESTED, DefaultValue, Nullable, datum/json/##PartialPath, list/datum/json/##PartialPath)

#define JSON_DATA(PartialPath, Version) \
/datum/json/##PartialPath/JSON_VERSION = Version; \
/datum/json/##PartialPath/JSON_ID = #PartialPath; \
/datum/json/##PartialPath

#define JSON_MIGRATION(PartialPath, Version) /datum/json/##PartialPath/proc/JSON_Migrate_From_Version_##Version(list/data)

/var/list/type_info_assoc_list = list()

/datum/json
    var/JSON_ID
    var/JSON_VERSION
    var/JSON_validation_error
    var/JSON_include_version = TRUE
    var/JSON_include_ID = TRUE
    var/list/JSON_migrable_versions

/datum/json/New(fileortext)
    . = ..()
    if(!type_info_assoc_list[JSON_ID])
        type_info_assoc_list[JSON_ID] = list()
        for(var/key in vars)
            if(!findtext(key, "JSON_TYPE_ANNOTATION_") == 1) continue
            var/stripped_key = copytext(key, 22)
            var/list/annotation = vars[key]
            type_info_assoc_list[JSON_ID][stripped_key] = annotation
    if(fileortext)
        Deserialize(fileortext)

/datum/json/proc/_is_List_Assoc(list/L)
#if (JSON_ASSOC_SCAN_MODE == 1)
    var/index = 0
    for(var/key in L)
        index++
        var/value = null
        if(!isnum(key) || (!(isnum(key) && index != key) && L[key] != key))
            value = L[key]
        if(!isnull(value))
            return TRUE
    return FALSE
#elif (JSON_ASSOC_SCAN_MODE == 2)
    return copytext(json_encode(L), 1, 2) == "{"
#else
#error JSON_ASSOC_SCAN_MODE is not a valid mode!
#endif


#ifdef JSON_TRUE_BOOLEANS
/datum/json/proc/_JSON_Serialize_To_List(check_types = TRUE, check_ID = TRUE, check_version = TRUE, check_nullable = TRUE, _include_version = null, _include_ID = null, true_token = null, false_token = null)
#else
/datum/json/proc/_JSON_Serialize_To_List(check_types = TRUE, check_ID = TRUE, check_version = TRUE, check_nullable = TRUE, _include_version = null, _include_ID = null)
#endif
    var/include_version = isnull(_include_version) ? JSON_include_version : _include_version
    var/include_ID = isnull(_include_ID) ? JSON_include_ID : _include_ID
    if(!Validate(check_types, check_ID, check_version, check_nullable, vars, JSON_VALIDATE_MODE_SERIALIZE))
        throw EXCEPTION("{JSON [JSON_ID]} Attempted to serialize invalid JSON! Validation error: [JSON_validation_error]")

    var/JSON_type_information = type_info_assoc_list[JSON_ID]
    var/list/intermediary = list()
    for(var/stripped_key in JSON_type_information)
        var/info = JSON_type_information[stripped_key]
        var/value = vars[stripped_key]
        if(isnull(value))
            intermediary[stripped_key] = vars[stripped_key]
            continue

        switch(info[JSON_TYPE_ANNOTATION_TYPE])
            if(JSON_TYPE_NUMBER)
                intermediary[stripped_key] = vars[stripped_key]

            if(JSON_TYPE_BOOLEAN)
#ifdef JSON_TRUE_BOOLEANS
                intermediary[stripped_key] = (vars[stripped_key] ? true_token : false_token)
#else
                intermediary[stripped_key] = vars[stripped_key]
#endif
            if(JSON_TYPE_STRING)
                intermediary[stripped_key] = vars[stripped_key]
            if(JSON_TYPE_LIST)
                intermediary[stripped_key] = vars[stripped_key]
            if(JSON_TYPE_LIST_NESTED)
                var/list/output = list()
                intermediary[stripped_key] = output
                var/list/datum/json/L = value
                for(var/datum/json/listvalue in L)
                    output[++output.len] = listvalue._JSON_Serialize_To_List(arglist(args))
            if(JSON_TYPE_ASSOC_LIST_NESTED)
                var/list/output = list()
                intermediary[stripped_key] = output
                var/list/datum/json/L = value
                for(var/key in L)
                    var/datum/json/listvalue = L[key]
                    output[key] = listvalue._JSON_Serialize_To_List(arglist(args))
            if(JSON_TYPE_NESTED)
                var/datum/json/nested = vars[stripped_key]
                intermediary[stripped_key] = nested._JSON_Serialize_To_List(arglist(args))
            else
                throw EXCEPTION("/datum/json/[JSON_ID]/var/[stripped_key] has an unknown type! Type: [info[JSON_TYPE_ANNOTATION_TYPE]]")

    if(include_ID) intermediary["JSON_ID"] = JSON_ID
    if(include_version) intermediary["JSON_VERSION"] = JSON_VERSION
    return intermediary

/datum/json/proc/Serialize(check_types = TRUE, check_ID = TRUE, check_version = TRUE, check_nullable = TRUE, include_version = null, include_ID = null)
    var/list/intermediary
#ifdef JSON_TRUE_BOOLEANS
    var/true_token = "JSON_TRUE_TOKEN{[rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)]}"
    var/false_token = "JSON_FALSE_TOKEN{[rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)][rand(0,9)]}"
    try
        intermediary = _JSON_Serialize_To_List(check_types, check_ID, check_version, check_nullable, include_version, include_ID, true_token, false_token)
#else
    try
        intermediary = _JSON_Serialize_To_List(check_types, check_ID, check_version, check_nullable, include_version, include_ID)
#endif
    catch(var/exception/e)
        JSON_validation_error = e.name
    var/output = json_encode(intermediary)
#ifdef JSON_TRUE_BOOLEANS
    output = replacetextEx(output, "\"[true_token]\"", "true")
    output = replacetextEx(output, "\"[false_token]\"", "false")
#endif
    return output

/datum/json/proc/_JSON_Deserialize_From_List(list/decoded, check_types = TRUE, check_ID = TRUE, check_version = TRUE, check_nullable = TRUE, enable_migration = TRUE)
    if(!islist(decoded))
        throw EXCEPTION("{JSON [JSON_ID]} decoded JSON is not an object!")

    if(isnull(decoded["JSON_ID"]))
        decoded["JSON_ID"] = JSON_ID
    if(isnull(decoded["JSON_VERSION"]))
        decoded["JSON_VERSION"] = JSON_VERSION

    var/decoded_JSON_ID = decoded["JSON_ID"]
    if(check_ID && decoded_JSON_ID != JSON_ID)
        throw EXCEPTION("{JSON [JSON_ID]} decoded_JSON_ID [decoded_JSON_ID] does not match JSON_ID [JSON_ID]")

    var/wanted_JSON_VERSION = initial(JSON_VERSION)
    var/current_JSON_VERSION = decoded["JSON_VERSION"]
    if(enable_migration && current_JSON_VERSION != wanted_JSON_VERSION)
        if(JSON_migrable_versions?.Find(decoded["JSON_VERSION"]) || hascall(src, "JSON_Migrate_From_Version_[decoded["JSON_VERSION"]]"))
            Migrate(decoded)
            if(check_version && decoded["JSON_VERSION"] != wanted_JSON_VERSION)
                throw EXCEPTION("{JSON [JSON_ID]} JSON migration from version [current_JSON_VERSION] has failed! Migrated version: [decoded["JSON_VERSION"]] Required version: [wanted_JSON_VERSION]")
        else if(check_version)
            throw EXCEPTION("{JSON [JSON_ID]} JSON_VERSION [current_JSON_VERSION] does not match JSON_VERSION [wanted_JSON_VERSION]")

    if(!Validate(check_types, check_ID, check_version, check_nullable, decoded, JSON_VALIDATE_MODE_DESERIALIZE))
        throw EXCEPTION("{JSON [JSON_ID]} attempted to deserialize invalid JSON! Validation error: [JSON_validation_error]")

    for(var/stripped_key in type_info_assoc_list[JSON_ID])
        var/info = type_info_assoc_list[JSON_ID][stripped_key]
        var/type = info[JSON_TYPE_ANNOTATION_TYPE]
        switch(type)
            if(JSON_TYPE_NESTED)
                var/list/nested_obj = decoded[stripped_key]
                if(isnull(nested_obj))
                    decoded[stripped_key] = null
                else
                    var/nested_type = info[JSON_TYPE_ANNOTATION_PREFIX]
                    var/datum/json/inst = new nested_type()
                    if(!inst._JSON_Deserialize_From_List(decoded[stripped_key], check_types, check_ID, check_version, check_nullable, enable_migration))
                        throw EXCEPTION("{JSON [JSON_ID]} attempted to deserialize invalid JSON! Nested([stripped_key]) validation error: [inst.JSON_validation_error]")
                    decoded[stripped_key] = inst
            if(JSON_TYPE_LIST_NESTED)
                var/list/datum/json/nested_obj = decoded[stripped_key]
                if(isnull(nested_obj))
                    decoded[stripped_key] = null
                else
                    var/nested_type = info[JSON_TYPE_ANNOTATION_PREFIX]
                    var/i = 0
                    for(var/list/nested in nested_obj)
                        i++
                        var/datum/json/inst = new nested_type()
                        if(!inst._JSON_Deserialize_From_List(nested, check_types, check_ID, check_version, check_nullable, enable_migration))
                            throw EXCEPTION("{JSON [JSON_ID]} attempted to deserialize invalid JSON! Nested([stripped_key]) validation error: [inst.JSON_validation_error]")
                        nested_obj[i] = inst
            if(JSON_TYPE_ASSOC_LIST_NESTED)
                var/list/datum/json/nested_obj = decoded[stripped_key]
                if(isnull(nested_obj))
                    decoded[stripped_key] = null
                else
                    var/nested_type = info[JSON_TYPE_ANNOTATION_PREFIX]
                    for(var/key in nested_obj)
                        var/list/nested = nested_obj[key]
                        var/datum/json/inst = new nested_type()
                        if(!inst._JSON_Deserialize_From_List(nested, check_types, check_ID, check_version, check_nullable, enable_migration))
                            throw EXCEPTION("{JSON [JSON_ID]} attempted to deserialize invalid JSON! Nested([stripped_key]) validation error: [inst.JSON_validation_error]")
                        nested_obj[key] = inst

    JSON_VERSION = decoded["JSON_VERSION"]
    var/JSON_type_information = type_info_assoc_list[JSON_ID]
    for(var/stripped_key in JSON_type_information)
        vars[stripped_key] = decoded[stripped_key]

    return TRUE

/datum/json/proc/Deserialize(json, check_types = TRUE, check_ID = TRUE, check_version = TRUE, check_nullable = TRUE, enable_migration = TRUE)
    . = FALSE
    if(!isfile(json) && !istext(json))
        JSON_validation_error = "Invalid input, expected a file or a string!"
        return
    if(isfile(json))
        json = file2text(json)

    var/ret
    try
        ret = _JSON_Deserialize_From_List(json_decode(json), check_types, check_ID, check_version, check_nullable, enable_migration)
    catch(var/exception/e)
        JSON_validation_error = e.name
        return
    return ret

/datum/json/proc/_JSON_isValidList(list/L)
    var/is_assoc = _is_List_Assoc(L)
    for(var/key in L)
        if(is_assoc)
            if(!isnum(key) && !istext(key)) return FALSE
            var/value = isnum(key) ? null : L[key]
            if(!isnull(value) && !istext(value) && !isnum(value))
                if(islist(value))
                    if(!_JSON_isValidList(value)) return FALSE
        else
            if(!isnull(key) && !istext(key) && !isnum(key))
                if(islist(key))
                    if(!_JSON_isValidList(key)) return FALSE
                else
                    return FALSE
    return TRUE

/datum/json/proc/Validate(check_types = TRUE, check_ID = TRUE, check_version = TRUE, check_nullable = TRUE, list/check_list = null, mode)
    . = FALSE
    if(mode != JSON_VALIDATE_MODE_DESERIALIZE && mode != JSON_VALIDATE_MODE_SERIALIZE)
        JSON_validation_error = "Unknown validation mode: [mode]"
        return
    JSON_validation_error = null
    if(check_ID && check_list["JSON_ID"] != initial(JSON_ID))
        JSON_validation_error = "JSON_ID has been modified! Required: [initial(JSON_ID)] Current: [check_list["JSON_ID"]]"
        return
    if(check_version && check_list["JSON_VERSION"] != initial(JSON_VERSION))
        JSON_validation_error = "JSON_VERSION does not match! Required: [initial(JSON_VERSION)] Current: [check_list["JSON_VERSION"]]"
        return

    var/JSON_type_information = type_info_assoc_list[JSON_ID]
    for(var/stripped_key in JSON_type_information)
        var/info = JSON_type_information[stripped_key]
        var/value = check_list[stripped_key]

        if(isnull(value))
            if(check_nullable && !info[JSON_TYPE_ANNOTATION_NULLABLE])
                JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] is not nullable but is null!"
                return
            continue

        if(check_types)
            switch(info[JSON_TYPE_ANNOTATION_TYPE])
                if(JSON_TYPE_NUMBER)
                    if(!isnum(value))
                        JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] is not a number! Value: [value]"
                        return
                if(JSON_TYPE_BOOLEAN)
                    var/true_boolean = (isnum(value) && (value == FALSE || value == TRUE))
                    if(!true_boolean)
                        JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] is not a boolean! Value: [value]"
                        return
                if(JSON_TYPE_STRING)
                    if(!istext(value))
                        JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] is not a string! Value: [value]"
                        return
                if(JSON_TYPE_LIST)
                    if(!islist(value))
                        JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] is not a list! Value: [value]"
                        return
                    if(!_JSON_isValidList(value))
                        JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] contains banned values! List: [json_encode(value)]"
                        return
                if(JSON_TYPE_LIST_NESTED)
                    if(!islist(value))
                        JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] is not a list! Value: [value]"
                        return
                    if(mode == JSON_VALIDATE_MODE_SERIALIZE)
                        var/type = info[JSON_TYPE_ANNOTATION_PREFIX]
                        for(var/listvalue in value)
                            if(!istype(listvalue, type))
                                JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] contains a non [type]!"
                                return
                    else
                        for(var/listvalue in value)
                            if(!islist(listvalue))
                                JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] contains a non list!"
                                return
                if(JSON_TYPE_ASSOC_LIST_NESTED)
                    if(!islist(value))
                        JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] is not a list! Value: [value]"
                        return
                    if(mode == JSON_VALIDATE_MODE_SERIALIZE)
                        var/type = info[JSON_TYPE_ANNOTATION_PREFIX]
                        for(var/key in value)
                            if(!istext(key))
                                JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] contains a non string as a key! Key: [key]"
                                return
                            var/listvalue = value[key]
                            if(!istype(listvalue, type))
                                JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] contains a non [type]!"
                                return
                    else
                        for(var/key in value)
                            if(!istext(key))
                                JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] contains a non string as a key! Key: [key]"
                                return
                            var/listvalue = value[key]
                            if(!islist(listvalue))
                                JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] contains a non list!"
                                return
                if(JSON_TYPE_NESTED)
                    if(mode == JSON_VALIDATE_MODE_SERIALIZE)
                        var/type = info[JSON_TYPE_ANNOTATION_PREFIX]
                        if(!istype(value, type))
                            JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] is not a [type]! Value: [value]"
                            return
                    else
                        if(!islist(value))
                            JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] is not a list! Value: [value]"
                            return
                else
                    JSON_validation_error = "/datum/json/[JSON_ID]/var/[stripped_key] has an unknown type! Type: [info[JSON_TYPE_ANNOTATION_TYPE]]"
                    return
    return TRUE

/datum/json/proc/operator<<(fileortext)
    if(!Deserialize(fileortext))
        throw EXCEPTION(JSON_validation_error)

/datum/json/proc/operator~()
    return Serialize()

/datum/json/proc/Migrate(list/data, wanted_version = initial(JSON_VERSION))
    while(data["JSON_VERSION"] < wanted_version)
        if(hascall(src, "JSON_Migrate_From_Version_[data["JSON_VERSION"]]"))
            call(src, "JSON_Migrate_From_Version_[data["JSON_VERSION"]]")(data)
            data["JSON_VERSION"]++
        else
            return

