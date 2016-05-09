/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBStructEncodingParser.h"

#import <algorithm>
#import <memory>
#import <string>
#import <unordered_set>
#import <vector>

#import "BaseType.h"

namespace {
  class _StringScanner {
  public:
    std::string string;
    size_t index;
    
    _StringScanner(std::string string): string(string), index(0) {}
    
    bool scanString(std::string stringToScan) {
      if (!(string.compare(index, stringToScan.length(), stringToScan) == 0)) {
        return false;
      }
      index += stringToScan.length();
      return true;
    }
    
    std::string scanUpToString(std::string upToString) {
      size_t pos = string.find(upToString, index);
      if (pos == std::string::npos) {
        // Mark as whole string scanned
        index = string.length();
        return "";
      }
      
      std::string inBetweenString = string.substr(index, pos - index);
      index = pos;
      return inBetweenString;
    }
    
    char currentCharacter() {
      return string[index];
    }
    
    std::string scanUpToCharacterFromSet(std::string &characterSet) {
      size_t pos = string.find_first_of(characterSet, index);
      if (pos == std::string::npos) {
        index = string.length();
        return "";
      }
      
      std::string inBetweenString = string.substr(index, pos-index);
      index = pos;
      return inBetweenString;
    }
  };
  
};

namespace FB { namespace RetainCycleDetector { namespace Parser {
  
  /**
   Intermediate struct object used inside the algorithm to pass some
   information when parsing nested structures.
   */
  struct _StructParseResult {
    std::vector<std::shared_ptr<Type>> containedTypes;
    std::string typeName;
  };
  
  static struct _StructParseResult _ParseStructEncodingWithScanner(_StringScanner &scanner) {
    std::vector<std::shared_ptr<BaseType>> types;
    
    // Every struct starts with '{'
    __unused bool scannedCorrectly = scanner.scanString("{");
    NSCAssert(scannedCorrectly, @"The first character of struct encoding should be {");
    
    // Parse name
    std::string structTypeName = scanner.scanUpToString("=");
    scanner.scanString("=");
    
    std::string literalEndingCharacters = "\"}";
    
    while (!(scanner.scanString("}"))) {
      if (scanner.scanString("\"")) {
        std::string parseResult = scanner.scanUpToString("\"");
        scanner.scanString("\"");
        if (parseResult.length() > 0) {
          types.emplace_back(std::shared_ptr<Unresolved>(new Unresolved(parseResult)));
        }
      } else if (scanner.currentCharacter() == '{') {
        // We do not want to consume '{' because we will call parser recursively
        size_t locBefore = scanner.index;
        _StructParseResult parseResult = _ParseStructEncodingWithScanner(scanner);
        
        std::shared_ptr<Unresolved> nameFromBefore = std::dynamic_pointer_cast<Unresolved>(types.back());
        NSCAssert(nameFromBefore, @"There should always be a name from before if we hit a struct");
        types.pop_back();
        std::shared_ptr<Struct> type (new Struct(nameFromBefore->value,
                                                 scanner.string.substr(locBefore, (scanner.index - locBefore)),
                                                 parseResult.typeName,
                                                 parseResult.containedTypes));
        
        types.emplace_back(type);
      } else {
        // It's a type name (literal), let's advance until we find '"', or '}'
        std::string parseResult = scanner.scanUpToCharacterFromSet(literalEndingCharacters);
        
        std::string nameFromBefore = "";
        if (types.size() > 0) {
          if (std::shared_ptr<Unresolved> maybeUnresolved = std::dynamic_pointer_cast<Unresolved>(types.back())) {
            nameFromBefore = maybeUnresolved->value;
            types.pop_back();
          }
        }
        std::shared_ptr<Type> type(new Type(nameFromBefore,
                                            parseResult));
        types.emplace_back(type);
      }
    }
    
    std::vector<std::shared_ptr<Type>> filteredVector;
    
    for (auto &t: types) {
      if (std::shared_ptr<Type> convertedType = std::dynamic_pointer_cast<Type>(t)) {
        filteredVector.emplace_back(convertedType);
      }
    }
    
    return {
      .containedTypes = filteredVector,
      .typeName = structTypeName,
    };
  }
  
  Struct parseStructEncoding(std::string structEncodingString) {
    return parseStructEncodingWithName(structEncodingString, "");
  }
  
  Struct parseStructEncodingWithName(std::string structEncodingString,
                                     std::string structName) {
    _StringScanner scanner = _StringScanner(structEncodingString);
    struct _StructParseResult result = _ParseStructEncodingWithScanner(scanner);
    
    Struct outerStruct = Struct(structName,
                                structEncodingString,
                                result.typeName,
                                result.containedTypes);
    outerStruct.passTypePath({});
    return outerStruct;
  }
} } }
