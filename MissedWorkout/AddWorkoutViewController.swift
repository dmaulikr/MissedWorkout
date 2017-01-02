//
//  ViewController.swift
//  AddWorkout
//
//  Created by Joseph Ross on 12/28/16.
//  Copyright © 2016 Joseph Ross. All rights reserved.
//

import UIKit
import HealthKit

class AddWorkoutViewController: UIViewController {
    
    let healthStore = HKHealthStore()
    @IBOutlet var workoutTypePicker: UIPickerView!
    let workoutTypePickerDelegate = WorkoutTypePickerDelegate()
    @IBOutlet var startDatePicker: UIDatePicker!
    @IBOutlet var durationPicker: UIPickerView!
    let durationPickerDelegate = NumberIntervalPickerDelegate(min: 5, max:360, interval:5)
    @IBOutlet var caloriesBurnedPicker: UIPickerView!
    let caloriesBurnedPickerDelegate = NumberIntervalPickerDelegate(min: 10, max: 1000, interval: 10)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let hkTypesToShare:Set<HKSampleType> = [HKWorkoutType.workoutType(),
                                                HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!]
        healthStore.requestAuthorization(toShare: hkTypesToShare, read: hkTypesToShare) { (success, error) in
            if !success {
                print("Failed to authorize with HealthKit!!")
                assertionFailure()
            }
        }
        
        workoutTypePicker.dataSource = workoutTypePickerDelegate
        workoutTypePicker.delegate = workoutTypePickerDelegate
        durationPicker.dataSource = durationPickerDelegate
        durationPicker.delegate = durationPickerDelegate
        caloriesBurnedPicker.dataSource = caloriesBurnedPickerDelegate
        caloriesBurnedPicker.delegate = caloriesBurnedPickerDelegate
        
        durationPicker.selectRow(durationPickerDelegate.index(of: 30), inComponent: 0, animated: false)
        caloriesBurnedPicker.selectRow(caloriesBurnedPickerDelegate.index(of: 70), inComponent: 0, animated: false)
        
        workoutTypePickerDelegate.valueChangedCallback = estimateCaloriesBurned
        durationPickerDelegate.valueChangedCallback = estimateCaloriesBurned
    }
    
    func estimateCaloriesBurned() {
        let workoutType = ActivityType.allTypes[workoutTypePicker.selectedRow(inComponent: 0)]
        let duration = durationPickerDelegate.values[durationPicker.selectedRow(inComponent: 0)]
        let estimate = Int(Double(duration) * workoutType.caloriesPerMinute)
        let estimateRow = caloriesBurnedPickerDelegate.index(of: estimate)
        caloriesBurnedPicker.selectRow(estimateRow, inComponent: 0, animated: true)
    }
    
    @IBAction func addWorkoutPressed() {
        
        var start = startDatePicker.date
        let duration = durationPickerDelegate.values[durationPicker.selectedRow(inComponent: 0)]
        let calories = caloriesBurnedPickerDelegate.values[caloriesBurnedPicker.selectedRow(inComponent: 0)]
        let activityType = ActivityType.allTypes[workoutTypePicker.selectedRow(inComponent: 0)]
        let end = start.addingTimeInterval(TimeInterval(60 * duration))
        let totalEnergy = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
        let workout = HKWorkout(activityType: activityType.hkActivityType, start: start, end: end, duration: 0, totalEnergyBurned: totalEnergy, totalDistance: nil, metadata: nil)
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        var samples:[HKQuantitySample] = []
        for _ in 1...duration {
            let caloriesForSample = Double(calories) / Double(duration)
            let sample = HKQuantitySample(type: activeEnergyType, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: caloriesForSample), start: start, end: start.addingTimeInterval(60))
            samples.append(sample)
            
            start = start.addingTimeInterval(60)
        }

        healthStore.save(workout) { (success, error) in
            if !success {
                print("Error saving workout: \(error)")
            }
            self.healthStore.add(samples, to: workout) { (success, error) in
                if !success {
                    print("Error adding sample to workout: \(error)")
                }
                
            }
        }
    }
}

struct ActivityType {
    static let crossTraining = ActivityType("Cross Training", hkActivityType:HKWorkoutActivityType.crossTraining, caloriesPerMinute: 6.667)
    static let climbing = ActivityType("Climbing", hkActivityType:HKWorkoutActivityType.climbing, caloriesPerMinute: 2.5)
    
    static let allTypes = [climbing, crossTraining]
    
    let title:String
    let hkActivityType:HKWorkoutActivityType
    let caloriesPerMinute:Double
    init(_ title:String, hkActivityType:HKWorkoutActivityType, caloriesPerMinute:Double) {
        self.title = title
        self.hkActivityType = hkActivityType
        self.caloriesPerMinute = caloriesPerMinute
    }
}

class WorkoutTypePickerDelegate: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
    var valueChangedCallback:(()->Void)?
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return ActivityType.allTypes.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return ActivityType.allTypes[row].title
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        valueChangedCallback?()
    }
}

class NumberIntervalPickerDelegate: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
    let values: [Int]
    let min: Int, max: Int, interval: Int
    var valueChangedCallback:(()->Void)?
    
    init(min: Int, max: Int, interval: Int) {
        self.min = min
        self.max = max
        self.interval = interval
        values = Array((min / interval)...(max / interval)).map { return $0 * interval }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return values.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(values[row])"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        valueChangedCallback?()
    }
    
    func index(of value:Int) -> Int {
        return value / interval - min / interval
    }
}
