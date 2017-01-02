//
//  ManageWorkoutsViewController.swift
//  MissedWorkout
//
//  Created by Joseph Ross on 1/1/17.
//  Copyright © 2017 Joseph Ross. All rights reserved.
//

import UIKit
import HealthKit

class ManageWorkoutsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let healthStore = HKHealthStore()
    
    @IBOutlet var tableView:UITableView! = nil
    
    var workouts:[Workout] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.setEditing(true, animated: false)
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addTarget(self, action: #selector(refreshWorkoutData), for: .valueChanged)
        refreshWorkoutData()
    }

    func refreshWorkoutData() {
        let source = HKSource.default()
        let predicate = HKQuery.predicateForObjects(from: source)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let workoutQuery = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { (query, samples, error) in
            if let error = error {
                NSLog("Error fetching my workouts: \(error)")
                return
            }
            let workouts = (samples ?? []).flatMap { $0 as? HKWorkout }
            
            let sampleQuery = HKSampleQuery(sampleType: HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { (query, samples, error) in
                if let error = error {
                    NSLog("Error fetching my workouts: \(error)")
                    return
                }
                DispatchQueue.main.async {
                    self.workouts = workouts.map { workout in
                        let workoutSamples = (samples ?? []).filter { sample in
                            if let sample = sample as? HKQuantitySample {
                                return sample.startDate >= workout.startDate && sample.startDate <= workout.endDate
                            }
                            return false
                        }
                        return Workout(hkWorkout: workout, samples:workoutSamples)
                    }
                    self.tableView.reloadData()
                }
            }
            self.healthStore.execute(sampleQuery)
        }
        healthStore.execute(workoutQuery)
        // Do any additional setup after loading the view.
        tableView.refreshControl?.endRefreshing()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return workouts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "WorkoutCell", for: indexPath)
        let workout = workouts[indexPath.row]
        cell.textLabel?.text = "\(workout.hkWorkout.workoutActivityType) - \(workout.hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0) kcal"
        cell.detailTextLabel?.text = "\(workout.hkWorkout.startDate)"
        return cell
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let workoutToDelete = workouts[indexPath.row]
            workouts.remove(at: indexPath.row)
            healthStore.delete(workoutToDelete.samples + [workoutToDelete.hkWorkout], withCompletion: { (success, error) in
                if !success, let error = error {
                    NSLog("Failed to delete workout \(workoutToDelete): \(error)")
                }
            })
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

}

class Workout {
    let hkWorkout:HKWorkout
    let samples:[HKSample]
    
    init(hkWorkout:HKWorkout, samples:[HKSample]) {
        self.hkWorkout = hkWorkout
        self.samples = samples
    }
}
