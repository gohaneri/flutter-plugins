import Flutter
import UIKit
import HealthKit

public class SwiftHealthPlugin: NSObject, FlutterPlugin {

    let healthStore = HKHealthStore()
    var healthDataTypes = [HKObjectType]()
    var heartRateEventTypes = Set<HKObjectType>()
    var allDataTypes = Set<HKObjectType>()
    var dataTypesDict: [String: HKQuantityType] = [:]
    var unitDict: [String: HKUnit] = [:]

    // Health Data Type Keys
    let ACTIVE_ENERGY_BURNED = "ACTIVE_ENERGY_BURNED"
    let BASAL_ENERGY_BURNED = "BASAL_ENERGY_BURNED"
    let BLOOD_GLUCOSE = "BLOOD_GLUCOSE"
    let BLOOD_OXYGEN = "BLOOD_OXYGEN"
    let BLOOD_PRESSURE_DIASTOLIC = "BLOOD_PRESSURE_DIASTOLIC"
    let BLOOD_PRESSURE_SYSTOLIC = "BLOOD_PRESSURE_SYSTOLIC"
    let BODY_FAT_PERCENTAGE = "BODY_FAT_PERCENTAGE"
    let BODY_MASS_INDEX = "BODY_MASS_INDEX"
    let BODY_TEMPERATURE = "BODY_TEMPERATURE"
    let ELECTRODERMAL_ACTIVITY = "ELECTRODERMAL_ACTIVITY"
    let HEART_RATE = "HEART_RATE"
    let HEART_RATE_VARIABILITY_SDNN = "HEART_RATE_VARIABILITY_SDNN"
    let HEIGHT = "HEIGHT"
    let HIGH_HEART_RATE_EVENT = "HIGH_HEART_RATE_EVENT"
    let IRREGULAR_HEART_RATE_EVENT = "IRREGULAR_HEART_RATE_EVENT"
    let LOW_HEART_RATE_EVENT = "LOW_HEART_RATE_EVENT"
    let RESTING_HEART_RATE = "RESTING_HEART_RATE"
    let STEPS = "STEPS"
    let WAIST_CIRCUMFERENCE = "WAIST_CIRCUMFERENCE"
    let WALKING_HEART_RATE = "WALKING_HEART_RATE"
    let WEIGHT = "WEIGHT"
    let DISTANCE_WALKING_RUNNING = "DISTANCE_WALKING_RUNNING"
    let FLIGHTS_CLIMBED = "FLIGHTS_CLIMBED"
    let WATER = "WATER"
    let MINDFULNESS = "MINDFULNESS"
    let SLEEP_IN_BED = "SLEEP_IN_BED"
    let SLEEP_ASLEEP = "SLEEP_ASLEEP"
    let SLEEP_AWAKE = "SLEEP_AWAKE"
    let MOVE_MINUTES = "MOVE_MINUTES"


    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_health", binaryMessenger: registrar.messenger())
        let instance = SwiftHealthPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Set up all data types
        initializeTypes()

        /// Handle checkIfHealthDataAvailable
        if (call.method.elementsEqual("checkIfHealthDataAvailable")){
            checkIfHealthDataAvailable(call: call, result: result)
        }
        /// Handle requestAuthorization
        else if (call.method.elementsEqual("requestAuthorization")){
            requestAuthorization(call: call, result: result)
        }

        /// Handle getData
        else if (call.method.elementsEqual("getData")){
            getData(call: call, result: result)
        }
    }

    func checkIfHealthDataAvailable(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(HKHealthStore.isHealthDataAvailable())
    }

    func requestAuthorization(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let types = (arguments?["types"] as? Array) ?? []

        var typesToRequest = Set<HKObjectType>()

        for key in types {
            let keyString = "\(key)"
            typesToRequest.insert(dataTypeLookUp(key: keyString))
        }

        if #available(iOS 11.0, *) {
            healthStore.requestAuthorization(toShare: nil, read: typesToRequest) { (success, error) in
                result(success)
            }
        }
        else {
            result(false)// Handle the error here.
        }
    }

    func getData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let dataTypeKey = (arguments?["dataTypeKey"] as? String) ?? "DEFAULT"
        let startDate = (arguments?["startDate"] as? NSNumber) ?? 0
        let endDate = (arguments?["endDate"] as? NSNumber) ?? 0

        // Convert dates from milliseconds to Date()
        let dateFrom = Date(timeIntervalSince1970: startDate.doubleValue / 1000)
        let dateTo = Date(timeIntervalSince1970: endDate.doubleValue / 1000)

        let dataType = dataTypeLookUp(key: dataTypeKey)
        let predicate = HKQuery.predicateForSamples(withStart: dateFrom, end: dateTo, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        var interval = DateComponents()
                interval.day = 1

        let query = HKStatisticsCollectionQuery(quantityType: dataType, quantitySamplePredicate: predicate, options: [.cumulativeSum], anchorDate: dateFrom as Date, intervalComponents:interval)

        query.initialResultsHandler = { query, results, error in
                if error != nil {
                    result(FlutterError(code: "FlutterHealth", message: "Results are null", details: "\(error!)"))
                    return
                }

                if let r = results {
                    var data = [NSDictionary]()
                    r.statistics().forEach({s in

                        data.append([
                            "uuid": "\(UUID())",
                            "value": s.sumQuantity()?.doubleValue(for: HKUnit.count()),
                            "date_from": Int(s.startDate.timeIntervalSince1970 * 1000),
                            "date_to": Int(s.endDate.timeIntervalSince1970 * 1000),
                        ])
                    })
                    print(data)
                    result(data)
                    return
                }
            }

            HKHealthStore().execute(query)

        /*
        let query = HKSampleQuery(sampleType: dataType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) {
            x, samplesOrNil, error in

            guard let samples = samplesOrNil as? [HKQuantitySample] else {
                guard let samplesCategory = samplesOrNil as? [HKCategorySample] else {
                    result(FlutterError(code: "FlutterHealth", message: "Results are null", details: "\(error!)"))
                    return
                }
                print(samplesCategory)
                result(samplesCategory.map { sample -> NSDictionary in
                    let unit = self.unitLookUp(key: dataTypeKey)

                    return [
                        "uuid": "\(sample.uuid)",
                        "value": sample.value,
                        "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                        "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                    ]
                })
                return
            }
            result(samples.map { sample -> NSDictionary in
                let unit = self.unitLookUp(key: dataTypeKey)

                return [
                    "uuid": "\(sample.uuid)",
                    "value": sample.quantity.doubleValue(for: unit),
                    "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                    "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                ]
            })
            return
        }
        HKHealthStore().execute(query)
 */
    }

    func unitLookUp(key: String) -> HKUnit {
        guard let unit = unitDict[key] else {
            return HKUnit.count()
        }
        return unit
    }

    func dataTypeLookUp(key: String) -> HKQuantityType {
        guard let dataType_ = dataTypesDict[key] else {
            return HKObjectType.quantityType(forIdentifier: .bodyMass)!
        }
        return dataType_
    }

    func initializeTypes() {
        unitDict[ACTIVE_ENERGY_BURNED] = HKUnit.kilocalorie()
        unitDict[BASAL_ENERGY_BURNED] = HKUnit.kilocalorie()
        unitDict[BLOOD_GLUCOSE] = HKUnit.init(from: "mg/dl")
        unitDict[BLOOD_OXYGEN] = HKUnit.percent()
        unitDict[BLOOD_PRESSURE_DIASTOLIC] = HKUnit.millimeterOfMercury()
        unitDict[BLOOD_PRESSURE_SYSTOLIC] = HKUnit.millimeterOfMercury()
        unitDict[BODY_FAT_PERCENTAGE] = HKUnit.percent()
        unitDict[BODY_MASS_INDEX] = HKUnit.init(from: "")
        unitDict[BODY_TEMPERATURE] = HKUnit.degreeCelsius()
        unitDict[ELECTRODERMAL_ACTIVITY] = HKUnit.siemen()
        unitDict[HEART_RATE] = HKUnit.init(from: "count/min")
        unitDict[HEART_RATE_VARIABILITY_SDNN] = HKUnit.secondUnit(with: .milli)
        unitDict[HEIGHT] = HKUnit.meter()
        unitDict[RESTING_HEART_RATE] = HKUnit.init(from: "count/min")
        unitDict[STEPS] = HKUnit.count()
        unitDict[WAIST_CIRCUMFERENCE] = HKUnit.meter()
        unitDict[WALKING_HEART_RATE] = HKUnit.init(from: "count/min")
        unitDict[WEIGHT] = HKUnit.gramUnit(with: .kilo)
        unitDict[DISTANCE_WALKING_RUNNING] = HKUnit.meter()
        unitDict[FLIGHTS_CLIMBED] = HKUnit.count()
        unitDict[WATER] = HKUnit.liter()
        unitDict[MINDFULNESS] = HKUnit.init(from: "")
        unitDict[SLEEP_IN_BED] = HKUnit.init(from: "")
        unitDict[SLEEP_ASLEEP] = HKUnit.init(from: "")
        unitDict[SLEEP_AWAKE] = HKUnit.init(from: "")
        unitDict[MOVE_MINUTES] = HKUnit.minute()

        // Set up iOS 11 specific types (ordinary health data types)
        if #available(iOS 11.0, *) {
            dataTypesDict[ACTIVE_ENERGY_BURNED] = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            dataTypesDict[BASAL_ENERGY_BURNED] = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
            dataTypesDict[BLOOD_GLUCOSE] = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
            dataTypesDict[BLOOD_OXYGEN] = HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!
            dataTypesDict[BLOOD_PRESSURE_DIASTOLIC] = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!
            dataTypesDict[BLOOD_PRESSURE_SYSTOLIC] = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!
            dataTypesDict[BODY_FAT_PERCENTAGE] = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
            dataTypesDict[BODY_MASS_INDEX] = HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!
            dataTypesDict[BODY_TEMPERATURE] = HKObjectType.quantityType(forIdentifier: .bodyTemperature)!
            dataTypesDict[ELECTRODERMAL_ACTIVITY] = HKObjectType.quantityType(forIdentifier: .electrodermalActivity)!
            dataTypesDict[HEART_RATE] = HKObjectType.quantityType(forIdentifier: .heartRate)!
            dataTypesDict[HEART_RATE_VARIABILITY_SDNN] = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
            dataTypesDict[HEIGHT] = HKObjectType.quantityType(forIdentifier: .height)!
            dataTypesDict[RESTING_HEART_RATE] = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
            dataTypesDict[STEPS] = HKObjectType.quantityType(forIdentifier: .stepCount)!
            dataTypesDict[WAIST_CIRCUMFERENCE] = HKObjectType.quantityType(forIdentifier: .waistCircumference)!
            dataTypesDict[WALKING_HEART_RATE] = HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!
            dataTypesDict[WEIGHT] = HKObjectType.quantityType(forIdentifier: .bodyMass)!
            dataTypesDict[DISTANCE_WALKING_RUNNING] = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
            dataTypesDict[FLIGHTS_CLIMBED] = HKObjectType.quantityType(forIdentifier: .flightsClimbed)!
            dataTypesDict[WATER] = HKObjectType.quantityType(forIdentifier: .dietaryWater)!
            //dataTypesDict[MINDFULNESS] = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
            //dataTypesDict[SLEEP_IN_BED] = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            //dataTypesDict[SLEEP_ASLEEP] = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            //dataTypesDict[SLEEP_AWAKE] = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            dataTypesDict[MOVE_MINUTES] = HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!

            healthDataTypes = Array(dataTypesDict.values)
        }
        // Set up heart rate data types specific to the apple watch, requires iOS 12
        /*
        if #available(iOS 12.2, *){
            dataTypesDict[HIGH_HEART_RATE_EVENT] = HKObjectType.categoryType(forIdentifier: .highHeartRateEvent)!
            dataTypesDict[LOW_HEART_RATE_EVENT] = HKObjectType.categoryType(forIdentifier: .lowHeartRateEvent)!
            dataTypesDict[IRREGULAR_HEART_RATE_EVENT] = HKObjectType.categoryType(forIdentifier: .irregularHeartRhythmEvent)!

            heartRateEventTypes =  Set([
                HKObjectType.categoryType(forIdentifier: .highHeartRateEvent)!,
                HKObjectType.categoryType(forIdentifier: .lowHeartRateEvent)!,
                HKObjectType.categoryType(forIdentifier: .irregularHeartRhythmEvent)!,
                ])
        }
        */

        // Concatenate heart events and health data types (both may be empty)
        allDataTypes = Set(heartRateEventTypes + healthDataTypes)
    }
}
