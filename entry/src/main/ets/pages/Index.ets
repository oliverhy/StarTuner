/*
 * 首页：透明玻璃视觉入口
 */

import { router } from '@kit.ArkUI';
import { ROUTE_TUNER, ROUTE_METRONOME, APP_NAME, APP_VERSION } from '../common/Constants';

@Entry
@Component
struct Index {
  @State showAbout: boolean = false;

  @Builder
  private AuroraBackground() {
    Column()
    .width('100%')
    .height('100%')
    .backgroundColor('#070B1C')
    .linearGradient({
      angle: 145,
      colors: [['#183C5C', 0.0], ['#0A1830', 0.28], ['#171337', 0.55], ['#071020', 0.76], ['#25151B', 1.0]]
    })
  }

  build() {
    Stack() {
      this.AuroraBackground()

      Column() {
        Row() {
          Image($r('app.media.brand_mark'))
            .width(58)
            .height(58)
            .objectFit(ImageFit.Contain)
          Column({ space: 3 }) {
            Text(APP_NAME)
              .fontSize(29)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FAFF')
            Text('让每一个音，都落在正确的位置')
              .fontSize(13)
              .fontColor('#A9B8DA')
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 10 })
          Blank()
          Text('PRO')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#6FEAFF')
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .borderRadius(12)
            .backgroundColor('#2635D6F4')
            .border({ width: 1, color: '#554DEBFF' })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 26, bottom: 18 })

        Text('选择练习工具')
          .width('100%')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#8FA2C9')
          .padding({ left: 24, bottom: 10 })

        Stack({ alignContent: Alignment.Center }) {
          Row() {
            Column({ space: 8 }) {
              Text('精准调音')
                .fontSize(25)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text('44 种乐器 · 实时音高')
                .fontSize(13)
                .fontColor('#B7C8E8')
              Row({ space: 6 }) {
                Text('进入调音器')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#72ECFF')
                Text('›')
                  .fontSize(21)
                  .fontColor('#72ECFF')
              }
              .margin({ top: 8 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Image($r('app.media.tuner_hero'))
              .width(132)
              .height(132)
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 22, right: 12 })
        }
        .width('90%')
        .height(190)
        .borderRadius(28)
        .backgroundColor('#291C2D4B')
        .backgroundBlurStyle(BlurStyle.Regular, { colorMode: ThemeColorMode.DARK })
        .border({ width: 1, color: '#3F78E9FF' })
        .shadow({ radius: 28, color: '#3328CBF2', offsetX: 0, offsetY: 14 })
        .onClick(() => router.pushUrl({ url: ROUTE_TUNER }))

        Stack({ alignContent: Alignment.Center }) {
          Row() {
            Column({ space: 8 }) {
              Text('强力节拍')
                .fontSize(25)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text('清晰穿透 · 锁屏练习')
                .fontSize(13)
                .fontColor('#C7BCE8')
              Row({ space: 6 }) {
                Text('进入节拍器')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFB762')
                Text('›')
                  .fontSize(21)
                  .fontColor('#FFB762')
              }
              .margin({ top: 8 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Image($r('app.media.metronome_hero'))
              .width(132)
              .height(132)
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 22, right: 12 })
        }
        .width('90%')
        .height(190)
        .margin({ top: 16 })
        .borderRadius(28)
        .backgroundColor('#291D193B')
        .backgroundBlurStyle(BlurStyle.Regular, { colorMode: ThemeColorMode.DARK })
        .border({ width: 1, color: '#43B58AFF' })
        .shadow({ radius: 28, color: '#2EB35CFF', offsetX: 0, offsetY: 14 })
        .onClick(() => router.pushUrl({ url: ROUTE_METRONOME }))

        Blank()

        Row() {
          Row({ space: 8 }) {
            Circle().width(7).height(7).fill('#68E8FF')
            Text(`音频引擎就绪  ·  v${APP_VERSION}`)
              .fontSize(11)
              .fontColor('#7788AD')
          }
          Blank()
          Row() {
            Text('关于')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#9DEEFF')
          }
          .width(64)
          .height(32)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .borderRadius(16)
          .backgroundColor('#25192A42')
          .border({ width: 1, color: '#376C8299' })
          .onClick(() => {
            this.showAbout = true;
          })
        }
        .width('88%')
        .margin({ bottom: 16 })
      }
      .width('100%')
      .height('100%')

      if (this.showAbout) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#B8050916')
            .onClick(() => {
              this.showAbout = false;
            })

          Column({ space: 16 }) {
            Row() {
              Image($r('app.media.brand_mark'))
                .width(54)
                .height(54)
                .objectFit(ImageFit.Contain)
              Column({ space: 3 }) {
                Text(APP_NAME)
                  .fontSize(21)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F7FAFF')
                Text(`版本 ${APP_VERSION}`)
                  .fontSize(12)
                  .fontColor('#72E8FF')
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 10 })
              Blank()
              Row() {
                Text('×')
                  .fontSize(22)
                  .fontColor('#A8B8D5')
              }
              .width(38)
              .height(38)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .borderRadius(19)
              .backgroundColor('#24172242')
              .onClick(() => {
                this.showAbout = false;
              })
            }
            .width('100%')

            Divider()
              .color('#315B7290')

            Column({ space: 8 }) {
              Text('为乐器练习打造的调音与节拍工具')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#EAF3FF')
              Text('支持 44 种乐器分类调音、实时音高检测、专业节拍音色、逐拍强弱、振动辅助和定时停止。')
                .fontSize(12)
                .lineHeight(20)
                .fontColor('#9DAECD')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              Text('联系与反馈')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F5F8FF')
              Row() {
                Text('邮箱')
                  .fontSize(11)
                  .fontColor('#8194B8')
                Blank()
                Text('39323856@qq.com')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#72E8FF')
              }
              .width('100%')
              .height(42)
              .padding({ left: 12, right: 12 })
              .borderRadius(14)
              .backgroundColor('#24142438')
              .border({ width: 1, color: '#2F657C91' })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              Text('隐私与权限')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F5F8FF')
              Text('麦克风仅用于本机实时音高分析；录音不会保存或上传。振动权限仅用于节拍反馈。')
                .fontSize(11)
                .lineHeight(18)
                .fontColor('#8FA2C3')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Text('© 2026 星辰调音节拍器')
              .width('100%')
              .fontSize(10)
              .fontColor('#687B9F')
              .textAlign(TextAlign.Center)

            Row() {
              Text('关闭')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#071321')
            }
            .width('100%')
            .height(44)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .borderRadius(22)
            .backgroundColor('#72E8FF')
            .onClick(() => {
              this.showAbout = false;
            })
          }
          .width('86%')
          .padding(20)
          .borderRadius(28)
          .backgroundColor('#ED11182B')
          .backgroundBlurStyle(BlurStyle.Regular, { colorMode: ThemeColorMode.DARK })
          .border({ width: 1, color: '#4B7AE6FF' })
          .shadow({ radius: 30, color: '#5526BEE8', offsetY: 12 })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
