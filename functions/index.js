const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

// Firestore ドキュメント作成時のトリガー
exports.someFunction = functions.firestore
    .document("users/{userId}")
    .onCreate((snap, context) => {
      console.log("新しいユーザー:", snap.data());
      return null;
    });


// Firestore ドキュメント更新時のトリガー
exports.deleteShiftOnDenial = functions.firestore
    .document("schedules/{scheduleId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      if (!beforeData || !afterData) {
        console.error("データが不正です");
        return null;
      }

      // denied が false から true に変更された場合のみ削除
      if (!beforeData.denied && afterData.denied === true) {
        await admin.firestore().collection("schedules")
            .doc(context.params.scheduleId)
            .delete();

        console.log(`スケジュール (${context.params.scheduleId}) を削除しました`);
      }

      return null;
    });

// PokerName の存在チェック
exports.checkPokerNameExists = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated", "Authentication required.",
    );
  }

  const pokerName = data.pokerName;
  if (!pokerName || typeof pokerName !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument", "PokerName is required and must be a string.",
    );
  }

  try {
    const usersRef = admin.firestore().collection("users");
    const snapshot = await usersRef.where(
        "pokerName", "==", pokerName).limit(1).get();

    return {exists: !snapshot.empty};
  } catch (error) {
    console.error("PokerName チェックエラー:", error);
    throw new functions.https.HttpsError("internal", "PokerName チェックに失敗しました。");
  }
});
