import 'dotenv/config'

const { APPCHAIN_CONF } = process.env
console.log("loaded config APPCHAIN_CONF: ", APPCHAIN_CONF)

if (!APPCHAIN_CONF) {
    console.log('[EXIT] Missing parameters!')
    process.exit(0)
}

export const conf = JSON.parse(APPCHAIN_CONF)
console.log('appchainConf', conf)