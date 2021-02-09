package cachet.plugins.health

import android.app.Activity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.request.DataReadRequest
import com.google.android.gms.fitness.result.DataReadResponse
import com.google.android.gms.fitness.data.*
import com.google.android.gms.fitness.request.SessionReadRequest
import com.google.android.gms.fitness.result.SessionReadResponse
import com.google.android.gms.tasks.Tasks
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import android.content.Intent
import android.os.Handler
import android.util.Log
import com.google.android.gms.fitness.FitnessActivities
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import java.text.DateFormat

const val GOOGLE_FIT_PERMISSIONS_REQUEST_CODE = 1111

class HealthPlugin(val activity: Activity, val channel: MethodChannel) : MethodCallHandler, ActivityResultListener, Result {

    private var result: Result? = null
    private var handler: Handler? = null

    private var BODY_FAT_PERCENTAGE = "BODY_FAT_PERCENTAGE"
    private var HEIGHT = "HEIGHT"
    private var WEIGHT = "WEIGHT"
    private var STEPS = "STEPS"
    private var ACTIVE_ENERGY_BURNED = "ACTIVE_ENERGY_BURNED"
    private var HEART_RATE = "HEART_RATE"
    private var BODY_TEMPERATURE = "BODY_TEMPERATURE"
    private var BLOOD_PRESSURE_SYSTOLIC = "BLOOD_PRESSURE_SYSTOLIC"
    private var BLOOD_PRESSURE_DIASTOLIC = "BLOOD_PRESSURE_DIASTOLIC"
    private var BLOOD_OXYGEN = "BLOOD_OXYGEN"
    private var BLOOD_GLUCOSE = "BLOOD_GLUCOSE"
    private var MOVE_MINUTES = "MOVE_MINUTES"
    private var DISTANCE_DELTA = "DISTANCE_DELTA"
    private var SLEEP_IN_BED = "SLEEP_IN_BED"
    private var SLEEP_ASLEEP = "SLEEP_ASLEEP"
    private var SLEEP_AWAKE = "SLEEP_AWAKE"

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "flutter_health")
            val plugin = HealthPlugin(registrar.activity(), channel)
            registrar.addActivityResultListener(plugin)
            channel.setMethodCallHandler(plugin)
        }
    }


    /// DataTypes to register
    private val fitnessOptions = FitnessOptions.builder()
            .addDataType(keyToHealthDataType(BODY_FAT_PERCENTAGE), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(HEIGHT), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(WEIGHT), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(STEPS), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(ACTIVE_ENERGY_BURNED), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(HEART_RATE), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(BODY_TEMPERATURE), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(BLOOD_PRESSURE_SYSTOLIC), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(BLOOD_OXYGEN), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(BLOOD_GLUCOSE), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(MOVE_MINUTES), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(DISTANCE_DELTA), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(SLEEP_IN_BED), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(SLEEP_ASLEEP), FitnessOptions.ACCESS_READ)
            .addDataType(keyToHealthDataType(SLEEP_AWAKE), FitnessOptions.ACCESS_READ)
            .build()


    override fun success(p0: Any?) {
        handler?.post(
                Runnable { result?.success(p0) })
    }

    override fun notImplemented() {
        handler?.post(
                Runnable { result?.notImplemented() })
    }

    override fun error(
            errorCode: String, errorMessage: String?, errorDetails: Any?) {
        handler?.post(
                Runnable { result?.error(errorCode, errorMessage, errorDetails) })
    }


    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == GOOGLE_FIT_PERMISSIONS_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                Log.d("FLUTTER_HEALTH", "Access Granted!")
                mResult?.success(true)
            } else if (resultCode == Activity.RESULT_CANCELED) {
                Log.d("FLUTTER_HEALTH", "Access Denied!")
                mResult?.success(false)
            }
        }
        return false
    }

    private var mResult: Result? = null

    private fun keyToHealthDataType(type: String): DataType {
        return when (type) {
            BODY_FAT_PERCENTAGE -> DataType.TYPE_BODY_FAT_PERCENTAGE
            HEIGHT -> DataType.TYPE_HEIGHT
            WEIGHT -> DataType.TYPE_WEIGHT
            STEPS -> DataType.TYPE_STEP_COUNT_DELTA
            ACTIVE_ENERGY_BURNED -> DataType.TYPE_CALORIES_EXPENDED
            HEART_RATE -> DataType.TYPE_HEART_RATE_BPM
            BODY_TEMPERATURE -> HealthDataTypes.TYPE_BODY_TEMPERATURE
            BLOOD_PRESSURE_SYSTOLIC -> HealthDataTypes.TYPE_BLOOD_PRESSURE
            BLOOD_PRESSURE_DIASTOLIC -> HealthDataTypes.TYPE_BLOOD_PRESSURE
            BLOOD_OXYGEN -> HealthDataTypes.TYPE_OXYGEN_SATURATION
            BLOOD_GLUCOSE -> HealthDataTypes.TYPE_BLOOD_GLUCOSE
            MOVE_MINUTES -> DataType.TYPE_MOVE_MINUTES
            DISTANCE_DELTA -> DataType.TYPE_DISTANCE_DELTA
            SLEEP_IN_BED, SLEEP_ASLEEP, SLEEP_AWAKE -> DataType.TYPE_SLEEP_SEGMENT
            else -> DataType.TYPE_STEP_COUNT_DELTA
        }
    }

    private fun getUnit(type: String): Field {
        return when (type) {
            BODY_FAT_PERCENTAGE -> Field.FIELD_PERCENTAGE
            HEIGHT -> Field.FIELD_HEIGHT
            WEIGHT -> Field.FIELD_WEIGHT
            STEPS -> Field.FIELD_STEPS
            ACTIVE_ENERGY_BURNED -> Field.FIELD_CALORIES
            HEART_RATE -> Field.FIELD_BPM
            BODY_TEMPERATURE -> HealthFields.FIELD_BODY_TEMPERATURE
            BLOOD_PRESSURE_SYSTOLIC -> HealthFields.FIELD_BLOOD_PRESSURE_SYSTOLIC
            BLOOD_PRESSURE_DIASTOLIC -> HealthFields.FIELD_BLOOD_PRESSURE_DIASTOLIC
            BLOOD_OXYGEN -> HealthFields.FIELD_OXYGEN_SATURATION
            BLOOD_GLUCOSE -> HealthFields.FIELD_BLOOD_GLUCOSE_LEVEL
            MOVE_MINUTES -> Field.FIELD_DURATION
            DISTANCE_DELTA -> Field.FIELD_DISTANCE
            SLEEP_IN_BED, SLEEP_ASLEEP, SLEEP_AWAKE -> Field.FIELD_SLEEP_SEGMENT_TYPE
            else -> Field.FIELD_PERCENTAGE
        }
    }

    /// Extracts the (numeric) value from a Health Data Point
    private fun getHealthDataValue(dataPoint: DataPoint, unit: Field): Any {
        return try {
            dataPoint.getValue(unit).asFloat()
        } catch (e1: Exception) {
            try {
                dataPoint.getValue(unit).asInt()
            } catch (e2: Exception) {
                try {
                    dataPoint.getValue(unit).asString()
                } catch (e3: Exception) {
                    Log.e("FLUTTER_HEALTH::ERROR", e3.toString())
                }
            }
        }
    }

    /// Called when the "getHealthDataByType" is invoked from Flutter
    private fun getData(call: MethodCall, result: Result) {
        val type = call.argument<String>("dataTypeKey")!!
        val startTime = call.argument<Long>("startDate")!!
        val endTime = call.argument<Long>("endDate")!!

        // Look up data type and unit for the type key
        val dataType = keyToHealthDataType(type)
        val unit = getUnit(type)

        if (dataType == DataType.TYPE_SLEEP_SEGMENT) {
            Log.d("FLUTTER_HEALTH", "Sleep data type")
            /// Start a new thread for doing a GoogleFit data lookup - using a Sessions Client
            thread {
                try {

                    val fitnessOptions = FitnessOptions.builder().addDataType(dataType).build()
                    val googleSignInAccount = GoogleSignIn.getAccountForExtension(activity.applicationContext, fitnessOptions)

                    val request = SessionReadRequest.Builder()
                            .read(DataType.TYPE_SLEEP_SEGMENT)
                            .setTimeInterval(startTime, endTime, TimeUnit.MILLISECONDS)
                            // By default, only activity sessions are included, so it is necessary to explicitly
                            // request sleep sessions. This will cause activity sessions to be *excluded*.
                            .includeSleepSessions()
                            .readSessionsFromAllApps()
                            .build()

                    val response =  Fitness.getSessionsClient(activity.applicationContext, googleSignInAccount)
                            .readSession(request)

                    // Get a list of the sessions that match the criteria to check the result.
                    val sessions: List<Session> = Tasks.await<SessionReadResponse>(response).sessions

                    val healthData : MutableList<HashMap<String,Any>> = mutableListOf()

                    sessions.forEach { session ->
                        response.result?.getDataSet(session)?.let { dataSets ->

                            //Log.d("FLUTTER_HEALTH", "$session")

                            healthData.add(hashMapOf(
                                    "value" to (session.getEndTime(TimeUnit.MILLISECONDS) - session.getStartTime(TimeUnit.MILLISECONDS)),
                                    "date_from" to session.getStartTime(TimeUnit.MILLISECONDS),
                                    "date_to" to session.getEndTime(TimeUnit.MILLISECONDS),
                                    "unit" to unit.toString()
                            ))

//                            dataSets.forEach { dataSet ->
//                                dataSet.dataPoints.forEach { point ->
//                                    val sleepStageVal = point.getValue(Field.FIELD_SLEEP_SEGMENT_TYPE).asInt()
//                                    val segmentStart = point.getStartTime(TimeUnit.MILLISECONDS)
//                                    val segmentEnd = point.getEndTime(TimeUnit.MILLISECONDS)
//                                    val durationMillis = segmentEnd - segmentStart
//
//
//
//                                    healthData.add(hashMapOf(
//                                            "value" to durationMillis,
//                                            "date_from" to segmentStart,
//                                            "date_to" to segmentEnd,
//                                            "unit" to unit.toString()
//                                    ))
//
////                                    when (sleepStageVal){
////                                        SleepStages.SLEEP -> {
////                                            val segmentStart = point.getStartTime(TimeUnit.MILLISECONDS)
////                                            val segmentEnd = point.getEndTime(TimeUnit.MILLISECONDS)
////                                            val durationMillis = segmentEnd - segmentStart
////
////                                            healthData.add(hashMapOf(
////                                                    "value" to durationMillis,
////                                                    "date_from" to segmentStart,
////                                                    "date_to" to segmentEnd,
////                                                    "unit" to unit.toString()
////                                            ))
////                                        }
////                                        SleepStages.AWAKE -> {}
////                                        SleepStages.SLEEP_LIGHT -> {}
////                                    }
//                                }
//                            }
                        }
                    }
                    activity.runOnUiThread { result.success(healthData) }
                } catch (e3: Exception) {
                    Log.d("FLUTTER_HEALTH", "$e3")
                    activity.runOnUiThread { result.success(null) }
                }
            }
        } else {
            Log.d("FLUTTER_HEALTH", "Other data type")
            /// Start a new thread for doing a GoogleFit data lookup - using a Fitness History Client
            thread {
                try {
                    val fitnessOptions = FitnessOptions.builder().addDataType(dataType).build()
                    val googleSignInAccount = GoogleSignIn.getAccountForExtension(activity.applicationContext, fitnessOptions)
                    val response = Fitness.getHistoryClient(activity.applicationContext, googleSignInAccount)
                            .readData(DataReadRequest.Builder()
                                    .read(dataType)
                                    .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
                                    .build())

                    /// Fetch all data points for the specified DataType
                    val dataPoints = Tasks.await<DataReadResponse>(response).getDataSet(dataType)

                    /// For each data point, extract the contents and send them to Flutter, along with date and unit.
                    val healthData = dataPoints.dataPoints.mapIndexed { _, dataPoint ->
                        return@mapIndexed hashMapOf(
                                "value" to getHealthDataValue(dataPoint, unit),
                                "date_from" to dataPoint.getStartTime(TimeUnit.MILLISECONDS),
                                "date_to" to dataPoint.getEndTime(TimeUnit.MILLISECONDS),
                                "unit" to unit.toString()
                        )
                    }
                    activity.runOnUiThread { result.success(healthData) }
                } catch (e3: Exception) {
                    Log.d("FLUTTER_HEALTH", "$e3")
                    activity.runOnUiThread { result.success(null) }
                }
            }
        }
    }

    private fun callToHealthTypes(call: MethodCall): FitnessOptions {
        val typesBuilder = FitnessOptions.builder()
        val args = call.arguments as HashMap<*, *>
        val types = args["types"] as ArrayList<*>
        for (typeKey in types) {
            if (typeKey !is String) continue
            typesBuilder.addDataType(keyToHealthDataType(typeKey), FitnessOptions.ACCESS_READ)
        }
        return typesBuilder.build()
    }

    /// Called when the "requestAuthorization" is invoked from Flutter 
    private fun requestAuthorization(call: MethodCall, result: Result) {
        val optionsToRegister = callToHealthTypes(call)
        mResult = result

        val isGranted = GoogleSignIn.hasPermissions(GoogleSignIn.getLastSignedInAccount(activity), fitnessOptions)

        /// Not granted? Ask for permission
        if (!isGranted) {
            GoogleSignIn.requestPermissions(
                    activity,
                    GOOGLE_FIT_PERMISSIONS_REQUEST_CODE,
                    GoogleSignIn.getLastSignedInAccount(activity),
                    optionsToRegister)
        }
        /// Permission already granted
        else {
            mResult?.success(true)
        }
    }

    /// Handle calls from the MethodChannel
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "requestAuthorization" -> requestAuthorization(call, result)
            "getData" -> getData(call, result)
            else -> result.notImplemented()
        }
    }

    // because this value is private field in Session
    fun Session.getValue(): Int {
        return when (this.activity) {
            FitnessActivities.SLEEP -> 72
            FitnessActivities.SLEEP_LIGHT -> 109
            FitnessActivities.SLEEP_DEEP -> 110
            FitnessActivities.SLEEP_REM -> 111
            FitnessActivities.SLEEP_AWAKE -> 112
            else -> throw Exception("session ${this.activity} is not supported")
        }
    }
}
