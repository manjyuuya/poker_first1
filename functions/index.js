const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.deleteShiftOnDenial = functions.firestore
    .document("schedules/{scheduleId}")
    .onUpdate((change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      console.log("Before Data:", beforeData);
      console.log("After Data:", afterData);

      // deniedがtrueに変更された場合に削除処理
      if (beforeData.denied !== true && afterData.denied === true) {
        return admin.firestore().collection("schedules")
            .doc(context.params.scheduleId)
            .delete()
            .then(() => {
              console.log("Schedule deleted successfully");
            })
            .catch((error) => {
              console.error("Error deleting schedule:", error);
            });
      }
      return null;
    });
