import Flutter
import UIKit
import HealthKit

public class SwiftHealthPlugin: NSObject, FlutterPlugin {

    let healthStore = HKHealthStore()
    var healthDataTypes = [HKObjectType]()
    var sleepHealthDataTypes = [HKObjectType]()
    var heartRateEventTypes = Set<HKObjectType>()
    var allDataTypes = Set<HKObjectType>()
    var sleepDataTypes = Set<HKObjectType>()
    var quantityDataTypesDict: [String: HKQuantityType] = [:]
    var categoryDataTypesDict: [String: HKCategoryType] = [:]
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
            let arguments = call.arguments as? NSDictionary
            let dataTypeKey = (arguments?["dataTypeKey"] as? String) ?? "DEFAULT"
            if(dataTypeKey == "SLEEP_IN_BED" || dataTypeKey == "SLEEP_ASLEEP" || dataTypeKey == "SLEEP_AWAKE"){
                getCategoryData(call: call, result: result)
            }else{
                getQuantityData(call: call, result: result)
            }
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
            typesToRequest.insert(dataTypeLookUpSleep(key: keyString))
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

    func getQuantityData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let dataTypeKey = (arguments?["dataTypeKey"] as? String) ?? "DEFAULT"
        let startDate = (arguments?["startDate"] as? NSNumber) ?? 0
        let endDate = (arguments?["endDate"] as? NSNumber) ?? 0

        // Convert dates from milliseconds to Date()
        let dateFrom = Date(timeIntervalSince1970: startDate.doubleValue / 1000)
        let dateTo = Date(timeIntervalSince1970: endDate.doubleValue / 1000)

        let dataType = dataTypeLookUp(key: dataTypeKey)

        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery.init(quantityType: dataType, quantitySamplePredicate: nil, options: [HKStatisticsOptions.cumulativeSum], anchorDate: dateFrom, intervalComponents: interval)

        query.initialResultsHandler = { query, results, error in
            if error != nil {
                result(FlutterError(code: "FlutterHealth", message: "Results are null", details: "\(error!)"))
                return
            }

            if let r = results {
                var data = [NSDictionary]()
                r.enumerateStatistics(from: dateFrom, to: dateTo) { (result, stop) in
                    if let v = result.sumQuantity() {

                        let unit = self.unitLookUp(key: dataTypeKey)
                        data.append([
                            "dataType":dataTypeKey,
                            "uuid": "\(UUID())",
                            "value": result.sumQuantity()?.doubleValue(for: unit) ?? 0,
                            "date_from": Int(result.startDate.timeIntervalSince1970 * 1000),
                            "date_to": Int(result.endDate.timeIntervalSince1970 * 1000),
                        ])
                    }
                }
                print(data)
                result(data)
                return
            }
        }

        HKHealthStore().execute(query)
    }

    func getCategoryData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let dataTypeKey = (arguments?["dataTypeKey"] as? String) ?? "DEFAULT"
        let startDate = (arguments?["startDate"] as? NSNumber) ?? 0
        let endDate = (arguments?["endDate"] as? NSNumber) ?? 0

        // Convert dates from milliseconds to Date()
        let dateFrom = Date(timeIntervalSince1970: startDate.doubleValue / 1000)
        let dateTo = Date(timeIntervalSince1970: endDate.doubleValue / 1000)
        let dataType = dataTypeLookUpSleep(key: dataTypeKey)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let yesterday = HKQuery.predicateForSamples(withStart: dateFrom, end: dateTo, options: [])
        let query = HKSampleQuery(sampleType: dataType, predicate: yesterday, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { x, samplesOrNil, error in

            var data = [NSDictionary]()
            if let result = samplesOrNil {
                print(result.count)
                for item in result {
                    if let sample = item as? HKCategorySample {
                        data.append([
                            "uuid": "\(sample.uuid)",
                            "value": sample.value,
                            "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                            "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                        ])
                    }
                }
            }
            result(data)
        }
        HKHealthStore().execute(query)
    }

    func unitLookUp(key: String) -> HKUnit {
        guard let unit = unitDict[key] else {
            return HKUnit.count()
        }
        return unit
    }

    func dataTypeLookUp(key: String) -> HKQuantityType {
        guard let dataType_ = quantityDataTypesDict[key] else {
            return HKObjectType.quantityType(forIdentifier: .stepCount)!
        }
        return dataType_
    }

    func dataTypeLookUpSleep(key: String) -> HKCategoryType {
        guard let dataType_ = categoryDataTypesDict[key] else {
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
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
            quantityDataTypesDict[ACTIVE_ENERGY_BURNED] = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            quantityDataTypesDict[BASAL_ENERGY_BURNED] = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
            quantityDataTypesDict[BLOOD_GLUCOSE] = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
            quantityDataTypesDict[BLOOD_OXYGEN] = HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!
            quantityDataTypesDict[BLOOD_PRESSURE_DIASTOLIC] = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!
            quantityDataTypesDict[BLOOD_PRESSURE_SYSTOLIC] = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!
            quantityDataTypesDict[BODY_FAT_PERCENTAGE] = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
            quantityDataTypesDict[BODY_MASS_INDEX] = HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!
            quantityDataTypesDict[BODY_TEMPERATURE] = HKObjectType.quantityType(forIdentifier: .bodyTemperature)!
            quantityDataTypesDict[ELECTRODERMAL_ACTIVITY] = HKObjectType.quantityType(forIdentifier: .electrodermalActivity)!
            quantityDataTypesDict[HEART_RATE] = HKObjectType.quantityType(forIdentifier: .heartRate)!
            quantityDataTypesDict[HEART_RATE_VARIABILITY_SDNN] = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
            quantityDataTypesDict[HEIGHT] = HKObjectType.quantityType(forIdentifier: .height)!
            quantityDataTypesDict[RESTING_HEART_RATE] = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
            quantityDataTypesDict[STEPS] = HKObjectType.quantityType(forIdentifier: .stepCount)!
            quantityDataTypesDict[WAIST_CIRCUMFERENCE] = HKObjectType.quantityType(forIdentifier: .waistCircumference)!
            quantityDataTypesDict[WALKING_HEART_RATE] = HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!
            quantityDataTypesDict[WEIGHT] = HKObjectType.quantityType(forIdentifier: .bodyMass)!
            quantityDataTypesDict[DISTANCE_WALKING_RUNNING] = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
            quantityDataTypesDict[FLIGHTS_CLIMBED] = HKObjectType.quantityType(forIdentifier: .flightsClimbed)!
            quantityDataTypesDict[WATER] = HKObjectType.quantityType(forIdentifier: .dietaryWater)!
            categoryDataTypesDict[MINDFULNESS] = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
            categoryDataTypesDict[SLEEP_IN_BED] = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            categoryDataTypesDict[SLEEP_ASLEEP] = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            categoryDataTypesDict[SLEEP_AWAKE] = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            quantityDataTypesDict[MOVE_MINUTES] = HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!

            healthDataTypes = Array(quantityDataTypesDict.values)
            sleepHealthDataTypes = Array(categoryDataTypesDict.values)
        }
        // Set up heart rate data types specific to the apple watch, requires iOS 12

        if #available(iOS 12.2, *){
            categoryDataTypesDict[HIGH_HEART_RATE_EVENT] = HKObjectType.categoryType(forIdentifier: .highHeartRateEvent)!
            categoryDataTypesDict[LOW_HEART_RATE_EVENT] = HKObjectType.categoryType(forIdentifier: .lowHeartRateEvent)!
            categoryDataTypesDict[IRREGULAR_HEART_RATE_EVENT] = HKObjectType.categoryType(forIdentifier: .irregularHeartRhythmEvent)!

            heartRateEventTypes =  Set([
                HKObjectType.categoryType(forIdentifier: .highHeartRateEvent)!,
                HKObjectType.categoryType(forIdentifier: .lowHeartRateEvent)!,
                HKObjectType.categoryType(forIdentifier: .irregularHeartRhythmEvent)!,
            ])
        }


        // Concatenate heart events and health data types (both may be empty)
        allDataTypes = Set(heartRateEventTypes + healthDataTypes + sleepHealthDataTypes)
    }
}
