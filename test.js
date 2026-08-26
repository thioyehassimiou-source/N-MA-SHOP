    var statusEl = document.getElementById('status');
    var videoEl = document.getElementById('video');
    var videoStream = null;
    var scanInterval = null;

    function setStatus(msg) {
      statusEl.textContent = msg;
    }

    function showSuccess() {
      document.getElementById('main-view').style.display = 'none';
      document.getElementById('success-view').style.display = 'flex';
    }

    function reset() {
      document.getElementById('manual-input').value = '';
      document.getElementById('photo-input').value = '';
      setStatus('');
      stopVideo();
      document.getElementById('success-view').style.display = 'none';
      document.getElementById('video-view').style.display = 'none';
      document.getElementById('main-view').style.display = 'block';
    }

    function stopVideo() {
      if (scanInterval) { clearInterval(scanInterval); scanInterval = null; }
      if (videoStream) {
        videoStream.getTracks().forEach(function(track) { track.stop(); });
        videoStream = null;
      }
      videoEl.srcObject = null;
    }

    function sendToPC(code) {
      setStatus('Envoi en cours...');
      var xhr = new XMLHttpRequest();
      xhr.open('POST', '/scan', true);
      xhr.onload = function() {
        if (xhr.status === 200) {
          showSuccess();
        } else {
          setStatus('Erreur serveur (' + xhr.status + '). Réessayez.');
        }
      };
      xhr.onerror = function() {
        setStatus('Impossible de joindre le PC. Vérifiez que vous êtes sur le même Wi-Fi.');
      };
      xhr.send(code);
    }

    // Bouton envoyer
    document.getElementById('send-btn').addEventListener('click', function() {
      var val = document.getElementById('manual-input').value.replace(/\s/g, '');
      if (val.length === 0) {
        setStatus('Saisissez un code avant d\'envoyer.');
        return;
      }
      sendToPC(val);
    });

    // Touche Entrée sur le champ
    document.getElementById('manual-input').addEventListener('keypress', function(e) {
      if (e.key === 'Enter' || e.keyCode === 13) {
        document.getElementById('send-btn').click();
      }
    });

    // Bouton reset
    document.getElementById('reset-btn').addEventListener('click', reset);
    document.getElementById('stop-video-btn').addEventListener('click', reset);

    // Live Webcam
    document.getElementById('live-btn').addEventListener('click', function() {
      if (typeof BarcodeDetector === 'undefined') {
        setStatus('Le scan en direct n\'est pas supporté par ce navigateur. Utilisez la photo ou la saisie manuelle.');
        return;
      }
      
      document.getElementById('main-view').style.display = 'none';
      document.getElementById('video-view').style.display = 'flex';
      document.getElementById('video-status').textContent = 'Initialisation de la caméra...';
      
      navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } })
        .then(function(stream) {
          videoStream = stream;
          videoEl.srcObject = stream;
          videoEl.play();
          
          var detector = new BarcodeDetector({
            formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'itf', 'codabar']
          });
          
          scanInterval = setInterval(function() {
            if (videoEl.readyState === videoEl.HAVE_ENOUGH_DATA) {
              detector.detect(videoEl).then(function(codes) {
                if (codes.length > 0) {
                  stopVideo();
                  sendToPC(codes[0].rawValue);
                }
              }).catch(function(e) {
                console.error(e);
              });
            }
          }, 500); // scan 2 times per second
        })
        .catch(function(err) {
          reset();
          setStatus('Impossible d\'accéder à la caméra: ' + err.message);
        });
    });

    // Photo avec BarcodeDetector natif (Android Chrome 83+)
    document.getElementById('photo-input').addEventListener('change', function(e) {
      var file = e.target.files[0];
      if (!file) return;

      if (typeof BarcodeDetector === 'undefined') {
        setStatus('Détection photo non disponible. Saisissez le code manuellement.');
        e.target.value = '';
        return;
      }

      setStatus('Analyse de la photo en cours...');
      
      // Redimensionner l'image pour éviter les problèmes mémoire sur mobile
      var img = new Image();
      var objectUrl = URL.createObjectURL(file);
      img.onload = function() {
        URL.revokeObjectURL(objectUrl);
        
        // Limiter à 1280px max pour économiser la mémoire
        var maxDim = 1280;
        var w = img.width, h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) { h = Math.round(h * maxDim / w); w = maxDim; }
          else { w = Math.round(w * maxDim / h); h = maxDim; }
        }
        
        var canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        var ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, w, h);
        
        var detector = new BarcodeDetector({
          formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'itf', 'codabar']
        });
        detector.detect(canvas).then(function(codes) {
          document.getElementById('photo-input').value = '';
          if (codes.length === 0) {
            setStatus('Aucun code détecté. Rapprochez-vous et re-prenez la photo, ou saisissez manuellement.');
          } else {
            sendToPC(codes[0].rawValue);
          }
        }).catch(function() {
          document.getElementById('photo-input').value = '';
          setStatus('Erreur d'analyse. Saisissez le code manuellement.');
        });
      };
      img.onerror = function() {
        URL.revokeObjectURL(objectUrl);
        setStatus('Impossible de lire la photo.');
        e.target.value = '';
      };
      img.src = objectUrl;
    });
