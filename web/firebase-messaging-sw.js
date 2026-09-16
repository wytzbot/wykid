importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCcVElxmcZxgeQvj6uM0ho8CAp8JlD_xuM",
  authDomain: "wykiddo.firebaseapp.com",
  projectId: "wykiddo",
  storageBucket: "wykiddo.firebasestorage.app",
  messagingSenderId: "107015497697",
  appId: "1:107015497697:web:8f63aba216b26b700594a0"
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || "Writing Kids";
  self.registration.showNotification(title, {
    body: payload.notification?.body || "Time for a little handwriting practice! ✏️",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png"
  });
});
