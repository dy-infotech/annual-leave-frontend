importScripts(
  "https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js"
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js"
);

firebase.initializeApp({
  apiKey: "AIzaSyAbnozWnMa3nVtRUDPwYg3x_NAy1D323bw",
  authDomain: "annual-leave-backend.firebaseapp.com",
  projectId: "annual-leave-backend",
  storageBucket: "annual-leave-backend.firebasestorage.app",
  messagingSenderId: "749318451543",
  appId: "1:749318451543:web:539e8efcc85e32e2d04e12"
});

const messaging = firebase.messaging();