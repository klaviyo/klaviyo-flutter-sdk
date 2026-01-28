//
//  ProfileKey+Ext.swift
//
//
//  Created on 1/14/26.
//

import Foundation
import KlaviyoSwift

extension Profile.ProfileKey {
    /// Converts a string key to a Profile.ProfileKey enum case
    /// - Parameter stringKey: The string key to convert
    /// - Returns: A ProfileKey enum case, using `.custom(customKey:)` for unrecognized keys
    static func from(_ stringKey: String) -> Profile.ProfileKey {
        switch stringKey.lowercased() {
        case "firstname", "first_name":
            return .firstName
        case "lastname", "last_name":
            return .lastName
        case "address1", "address_1":
            return .address1
        case "address2", "address_2":
            return .address2
        case "title":
            return .title
        case "organization":
            return .organization
        case "city":
            return .city
        case "region":
            return .region
        case "country":
            return .country
        case "zip":
            return .zip
        case "image":
            return .image
        case "latitude":
            return .latitude
        case "longitude":
            return .longitude
        default:
            return .custom(customKey: stringKey)
        }
    }
}
