# iMessage-Sticker-Util
iMessage extension utility functions.

See: http://www.exoviz.com/2018/01/15/creating-dynamic-stickers-for-imessage/

## Example Usage

```Swift
do {
    if let sticker = image.createSticker("my sticker") {
      self.activeConversation?.insert(sticker, completionHandler: {
          (error) in
        if let error = error {
            print(error)
        }
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch { }
      })
    }
} catch {
    print("Failed to create sticker: \(error)")
}

```
