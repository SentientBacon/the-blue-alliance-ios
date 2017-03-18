//
//  TBAColorExtension.swift
//  the-blue-alliance-ios
//
//  Created by Zach Orr on 3/17/17.
//  Copyright © 2017 The Blue Alliance. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {
    
    public class var primaryBlue: UIColor {
        return UIColor.color(red: 63, green: 81, blue: 181)
    }

    public class var primaryDarkBlue: UIColor {
        return UIColor.color(red: 48, green: 63, blue: 159)
    }

    class func color(red: Double, green: Double, blue: Double) -> UIColor {
        return UIColor(red: CGFloat(red/255.0), green: CGFloat(green/255.0), blue: CGFloat(blue/255.0), alpha: 1.0)
    }
    
}
