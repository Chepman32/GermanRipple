#!/usr/bin/env python3
"""Generate deterministic geometric app assets using only Python's standard library."""
from pathlib import Path
import json,math,struct,zlib
ROOT=Path(__file__).resolve().parents[1]/'App/Resources'
def plist(path,data):
    def xml(v):
        if isinstance(v,bool):return '<true/>' if v else '<false/>'
        if isinstance(v,int):return '<integer>'+str(v)+'</integer>'
        if isinstance(v,str):return '<string>'+v.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')+'</string>'
        if isinstance(v,list):return '<array>'+''.join(map(xml,v))+'</array>'
        return '<dict>'+''.join('<key>'+k+'</key>'+xml(value) for k,value in v.items())+'</dict>'
    path.write_text('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">'+xml(data)+'</plist>\n')
def png(path,bg,fg):
    rgb=lambda h:tuple(int(h[1+i*2:3+i*2],16) for i in range(3))
    bg,fg=rgb(bg),rgb(fg);rows=bytearray()
    circles=[(455+i*17,540-i*14,r) for i,r in enumerate([90,180,280,390])]
    for y in range(1024):
        rows.append(0)
        for x in range(1024):
            d=min(abs(math.hypot(x-cx,y-cy)-r) for cx,cy,r in circles)
            alpha=max(0,min(1,6.5-d))
            if math.hypot(x-455,y-540)<20:alpha=1
            rows.extend(round(a+(b-a)*alpha) for a,b in zip(bg,fg))
    def chunk(name,data):return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1024,1024,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(rows),9))+chunk(b'IEND',b''))
def main():
    assets=ROOT/'Assets.xcassets';assets.mkdir(parents=True,exist_ok=True)
    info={'author':'xcode','version':1}
    (assets/'Contents.json').write_text(json.dumps({'info':info},indent=2))
    colors={'AccentColor':('#3B4BCC','#AAB6FF'),'OnAccent':('#FFFFFF','#151726'),'SecondaryText':('#5C5F70','#ABB0C3'),'Attention':('#885800','#E6BC6A'),'Success':('#247047','#86CFA3'),'Error':('#B02C3A','#F69BA7'),'LaunchBackground':('#F4F5FA','#11121A')}
    for name,variants in colors.items():
        directory=assets/(name+'.colorset');directory.mkdir(exist_ok=True);items=[]
        for i,h in enumerate(variants):
            values={key:str(int(h[1+j*2:3+j*2],16)/255) for j,key in enumerate(['red','green','blue'])};values['alpha']='1.000'
            item={'idiom':'universal','color':{'color-space':'srgb','components':values}}
            if i:item['appearances']=[{'appearance':'luminosity','value':'dark'}]
            items.append(item)
        (directory/'Contents.json').write_text(json.dumps({'colors':items,'info':info},indent=2))
    directory=assets/'AppIcon.appiconset';directory.mkdir(exist_ok=True)
    for variant,bg,fg in [('light','#3B4BCC','#FFFFFF'),('dark','#151726','#AAB6FF')]:png(directory/f'Icon-{variant}.png',bg,fg)
    items=[{'filename':'Icon-light.png','idiom':'universal','platform':'ios','size':'1024x1024'},{'filename':'Icon-dark.png','idiom':'universal','platform':'ios','size':'1024x1024','appearances':[{'appearance':'luminosity','value':'dark'}]}]
    (directory/'Contents.json').write_text(json.dumps({'images':items,'info':info},indent=2))
    plist(ROOT/'RemoteConfigDefaults.plist',{'content_version_de_en':1,'min_supported_app_version':'1.0.0','free_daily_chains':3,'paywall_enabled':True,'peel_free':False,'maintenance_message':'','sync_enabled':True,'scheduler_weights':json.dumps({'overdue':3,'weakness':2,'introduction':1.5,'overlap':2,'themeVariety':0.5})})
    collected=[('NSPrivacyCollectedDataTypeUserID',True,['NSPrivacyCollectedDataTypePurposeAppFunctionality']),('NSPrivacyCollectedDataTypeProductInteraction',False,['NSPrivacyCollectedDataTypePurposeAnalytics']),('NSPrivacyCollectedDataTypeCrashData',False,['NSPrivacyCollectedDataTypePurposeAnalytics']),('NSPrivacyCollectedDataTypeOtherUserContent',True,['NSPrivacyCollectedDataTypePurposeAppFunctionality'])]
    plist(ROOT/'PrivacyInfo.xcprivacy',{'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyAccessedAPITypes':[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1']}],'NSPrivacyCollectedDataTypes':[{'NSPrivacyCollectedDataType':k,'NSPrivacyCollectedDataTypeLinked':linked,'NSPrivacyCollectedDataTypeTracking':False,'NSPrivacyCollectedDataTypePurposes':purposes} for k,linked,purposes in collected]})
    loc=lambda name,desc:[{'description':desc,'displayName':name,'locale':'en_US'}]
    products=[{'displayPrice':'79.99','familyShareable':False,'internalID':'7B402733','localizations':loc('Ripple Pro Lifetime','Unlimited practice and Peel mode, with a single purchase.'),'productID':'app.ripple.pro.lifetime','referenceName':'Pro Lifetime','type':'NonConsumable'}]
    subs=[]
    for i,name,price,period in [(1,'Yearly','39.99','P1Y'),(2,'Monthly','5.99','P1M')]:
        subs.append({'adHocOffers':[],'codeOffers':[],'displayPrice':price,'familyShareable':False,'groupNumber':1,'internalID':f'9815700{i}','introductoryOffer':{'internalID':'98157009','numberOfPeriods':1,'paymentMode':'free','subscriptionPeriod':'P1W'} if i==1 else None,'localizations':loc('Ripple Pro '+name,'Unlimited chains, Peel mode and focused rule practice.'),'productID':'app.ripple.pro.'+name.lower(),'recurringSubscriptionPeriod':period,'referenceName':'Pro '+name,'subscriptionGroupID':'73110','type':'RecurringSubscription'})
    config={'identifier':'A1D6B811','nonRenewingSubscriptions':[],'products':products,'settings':{'_applicationInternalID':'','_developerTeamID':'','_failTransactionsEnabled':False,'_locale':'en_US','_storefront':'USA','_storeKitErrors':[]},'subscriptionGroups':[{'id':'73110','localizations':[],'name':'Ripple Pro','subscriptions':subs}],'version':{'major':3,'minor':0}}
    (ROOT/'Ripple.storekit').write_text(json.dumps(config,indent=2)+'\n')
    print('Created app icons, semantic colors, privacy manifest, Remote Config defaults and StoreKit configuration.')
if __name__=='__main__':main()
