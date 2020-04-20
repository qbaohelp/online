#!/usr/bin/env node

const CryptoJS = require('crypto-js');
const axios = require('axios');
const qs = require('qs');

/**
 * AES加密的配置
 * 1.密钥
 * 2.算法模式ECB
 * 3.补全值
 */
var AES_conf = {
    mode: CryptoJS.mode.ECB, //模式
    padding: CryptoJS.pad.Pkcs7 //补全值
}

/**
 * 加密
 * @return utf8
 */
function encryption(data, key) {
    var raw = CryptoJS.enc.Utf8.parse(data)
    var n = CryptoJS.enc.Utf8.parse(key)
    var encryptedText = CryptoJS.AES.encrypt(raw, n, {
        mode: AES_conf.mode,
        padding: AES_conf.padding
    });
    return encryptedText.toString();
}

/**
 * 解密
 * @return utf8
 */
function decryption(data, key) {
    var n = CryptoJS.enc.Utf8.parse(key)
    var decryptedText = CryptoJS.AES.decrypt(data, n, {
        mode: AES_conf.mode,
        padding: AES_conf.padding
    });
    return CryptoJS.enc.Utf8.stringify(decryptedText).toString();
}

// axios 默认配置 更多配置查看Axios中文文档
axios.defaults.timeout = 2500; // 超时默认值
axios.defaults.baseURL = 'https://lncn.org'; // 默认baseURL
axios.defaults.headers.common['Pragma'] = 'no-cache';
axios.defaults.headers.common['Cache-Control'] = 'no-cache';
axios.defaults.headers.common['Content-Type'] = 'application/json;charset=UTF-8';
axios.defaults.headers.post['Content-Type'] = 'application/x-www-form-urlencoded;charset=UTF-8';

// 响应拦截器
// axios.interceptors.response.use(
//     response => {
//         // 如果返回的状态码为200，说明接口请求成功，可以正常拿到数据
//         // 否则的话抛出错误
//         if (response.status === 200) {
//             return Promise.resolve(response);
//         } else {
//             return Promise.reject(response);
//         }
//     },
//     // 下面列举几个常见的操作，其他需求可自行扩展
//     error => {
//         if (error.response.status) {
//             switch (error.response.status) {
//                 // 404请求不存在
//                 case 404:
//                     break;
//                 // 其他错误，直接抛出错误提示
//                 default:
//             }
//             return Promise.reject(error.response);
//         }
//     }
// })

/**
 * get方法，对应get请求
 * @param {String} url [请求的url地址]
 * @param {Object} params [请求时携带的参数]
 */
function get(url, params) {
    return new Promise((resolve, reject) => {
        axios.get(url, {
            params: params
        }).then(res => {
            resolve(res.data);
        }).catch(err => {
            // console.log(err);
            // reject(err.data)
        })
    });
}

/**
 * post方法，对应post请求
 * @param {String} url [请求的url地址]
 * @param {Object} params [请求时携带的参数]
 */
function post(url/*, params*/) {
    return new Promise((resolve, reject) => {
        axios.post(url/*, qs.stringify(params)*/).then(res => {
            console.log(res);
            resolve(res.data);
        }).catch(err => {
            // console.log(err);
            // reject(err.data)
        })
    });
}

async function getss(ssr, ssrUrl) {
    if (ssr.name.indexOf("更新") != -1) {
        return;
    }
    var param = ssr.ip + ':' + ssr.port;
    await get('/api/ss', {'target': param}).then(res => {
        if (res != undefined) {
            console.log(ssr.name + '|' + res + ',' + ssrUrl);
        }
    });
}

var arguments = process.argv.splice(2);
// console.log('所传递的参数是：', arguments.length);
if (arguments.length >= 2 && arguments[0].length > 0) {
    var ssr_array = decryption(arguments[0], arguments[1]);
    if (ssr_array.length > 0) {
        var json_array = JSON.parse(ssr_array);
        // console.log("json_ssr array size:" + json_array.length);
        for (i = 0; i < json_array.length; i++) {
            var json = json_array[i];
            getss(json.ssr, json.ssrUrl);
        }
    }
}
