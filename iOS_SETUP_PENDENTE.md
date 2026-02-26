# iOS Setup Pendente - Nutro AI

## Status Atual

| Item | Status |
|------|--------|
| GoogleService-Info.plist | ✅ Configurado |
| Bundle ID (`br.com.snapdark.apps.nutreai`) | ✅ Configurado |
| AppDelegate.swift com Firebase | ✅ Configurado |
| Pacotes Flutter (firebase_core, firebase_messaging) | ✅ Configurado |

---

## Pendente para Push Notifications funcionar no iOS

### 1. Criar chave APNs no Apple Developer Portal

1. Acesse: https://developer.apple.com/account/resources/authkeys/list
2. Clique em **"+"** para criar uma nova chave
3. Dê um nome (ex: "Nutro AI Push Key")
4. Marque **"Apple Push Notifications service (APNs)"**
5. Clique em **"Continue"** e depois **"Register"**
6. **BAIXE A CHAVE (.p8)** - só pode baixar uma vez!
7. Anote o **Key ID** (ex: ABC123DEFG)

### 2. Upload da chave APNs no Firebase Console

1. Acesse: https://console.firebase.google.com/project/apps-2ba2f/settings/cloudmessaging
2. Na seção **"Apple app configuration"**, encontre o app iOS
3. Clique em **"Upload"** na seção APNs Authentication Key
4. Faça upload do arquivo **.p8** que você baixou
5. Preencha:
   - **Key ID**: O ID da chave que você anotou
   - **Team ID**: Seu Apple Developer Team ID (encontre em https://developer.apple.com/account -> Membership)

### 3. Habilitar Push Notifications no Xcode (quando for buildar)

1. Abra o projeto no Xcode (`ios/Runner.xcworkspace`)
2. Selecione o target **Runner**
3. Vá em **Signing & Capabilities**
4. Clique em **"+ Capability"**
5. Adicione **"Push Notifications"**
6. Adicione **"Background Modes"** e marque:
   - Remote notifications
   - Background fetch

### 4. Gerar Podfile e instalar dependências (no Mac)

```bash
cd ios
flutter pub get
pod install
```

---

## Informações do Projeto

- **Bundle ID iOS**: `br.com.snapdark.apps.nutreai`
- **Firebase Project ID**: `apps-2ba2f`
- **GCM Sender ID**: `853860056867`

---

## Checklist Final

- [ ] Chave APNs criada no Apple Developer Portal
- [ ] Chave APNs (.p8) uploaded no Firebase Console
- [ ] Push Notifications capability adicionado no Xcode
- [ ] Background Modes configurado no Xcode
- [ ] Pod install executado no Mac
- [ ] Build de teste no dispositivo iOS real

---

**Nota**: Push notifications no iOS só funcionam em dispositivos físicos, não no simulador.
